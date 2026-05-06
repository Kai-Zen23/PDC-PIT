import json
from channels.generic.websocket import AsyncWebsocketConsumer
from asgiref.sync import sync_to_async
from .models import Match
from .engine import GameEngine
import random

class GameConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.match_id = self.scope['url_route']['kwargs']['match_id']
        self.room_group_name = f'match_{self.match_id}'
        self.username = self.scope.get('query_string', b'').decode()

        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name
        )
        await self.accept()
        
        print(f"[WS] User connected to match {self.match_id}. Query: {self.scope.get('query_string', b'').decode()}")

        # Auto-start: if match is in_progress with both players but no game state yet,
        # broadcast player_joined so the frontend knows to trigger start_game.
        match = await self.get_match()
        if match and match.status == 'in_progress':
            if not match.state:
                # Game not yet started — notify all connected clients
                await self.channel_layer.group_send(
                    self.room_group_name,
                    {'type': 'game_message', 'event_type': 'player_joined', 'state': {}}
                )
            else:
                # Game already running — send current state to the newly connected client
                if match.state and 'players' in match.state:
                    await self.send(text_data=json.dumps({
                        'event': 'game_start',
                        'state': match.state
                    }))
                else:
                    # State exists but is empty/invalid — treat as joined but not started
                    await self.channel_layer.group_send(
                        self.room_group_name,
                        {'type': 'game_message', 'event_type': 'player_joined', 'state': {}}
                    )

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(
            self.room_group_name,
            self.channel_name
        )
        cancelled = await self.handle_disconnect()
        if cancelled:
            await self.channel_layer.group_send(
                self.room_group_name,
                {'type': 'game_message', 'event_type': 'match_cancelled', 'state': {}}
            )

    async def receive(self, text_data):
        data = json.loads(text_data)
        action = data.get('action')
        username = data.get('username')
        
        match = await self.get_match()
        if not match:
            return

        state = match.state
        
        if action == 'start_game':
            print(f"[WS] start_game received for match {self.match_id} from {username}. Status: {match.status}, HasState: {bool(state)}")
            if match.status == 'in_progress' and not state:
                state = GameEngine.create_initial_state(match.player1.username, match.player2.username)
                state = GameEngine.start_round(state)
                await self.save_state(match, state)
                await self.broadcast_state(state, 'game_start')
                print(f"[WS] Match {self.match_id} started successfully.")
        
        elif action == 'draw_card':
            if state["current_turn"] == username and not state["players"][username]["has_stood"] and state["players"][username]["turns_taken"] < 3 and len(state["players"][username]["visible_cards"]) + len(state["players"][username]["hidden_cards"]) < 4:
                card = state["deck"].pop()
                state["players"][username]["visible_cards"].append(card)
                state["players"][username]["turns_taken"] += 1
                
                if state["players"][username]["turns_taken"] >= 3:
                    state["players"][username]["has_stood"] = True
                
                GameEngine.switch_turn(state)
                state = GameEngine.check_round_end(state)
                await self.save_state(match, state)
                await self.broadcast_state(state, 'turn_update')
                
        elif action == 'stand':
            if state["current_turn"] == username and not state["players"][username]["has_stood"]:
                state["players"][username]["has_stood"] = True
                GameEngine.switch_turn(state)
                state = GameEngine.check_round_end(state)
                await self.save_state(match, state)
                await self.broadcast_state(state, 'turn_update')
                
        elif action == 'use_powerup':
            powerup = data.get('powerup')
            if state["current_turn"] == username and state["players"][username]["powerups_used_this_round"] < 1:
                if powerup in state["players"][username]["powerups"]:
                    state["players"][username]["powerups"].remove(powerup)
                    state["players"][username]["powerups_used_this_round"] += 1
                    
                    # Apply powerup
                    opponent = state["p2"] if username == state["p1"] else state["p1"]
                    if powerup == 1: # Remove random opponent card
                        if state["players"][opponent]["visible_cards"]:
                            state["players"][opponent]["visible_cards"].pop(random.randrange(len(state["players"][opponent]["visible_cards"])))
                    elif powerup == 2: # Remove opponent last card
                        if state["players"][opponent]["visible_cards"]:
                            state["players"][opponent]["visible_cards"].pop()
                    elif powerup == 3: # Remove own last card
                        if state["players"][username]["visible_cards"]:
                            state["players"][username]["visible_cards"].pop()
                    elif powerup == 4: # Remove own last 2 cards
                        if state["players"][username]["visible_cards"]:
                            state["players"][username]["visible_cards"].pop()
                        if state["players"][username]["visible_cards"]:
                            state["players"][username]["visible_cards"].pop()
                    elif powerup == 5: # Target override
                        if not state["players"][username]["target_override_used"]:
                            target_choice = data.get('target_choice', 21)
                            if target_choice in [19, 21, 28]:
                                state["target_number"] = target_choice
                                state["players"][username]["target_override_used"] = True
                    
                    state = GameEngine.check_round_end(state)
                    await self.save_state(match, state)
                    await self.broadcast_state(state, 'powerup_used')

        elif action == 'next_round':
            if state["status"] != "finished":
                state = GameEngine.start_round(state)
                await self.save_state(match, state)
                await self.broadcast_state(state, 'game_start')

    @sync_to_async
    def get_match(self):
        try:
            return Match.objects.get(id=self.match_id)
        except Match.DoesNotExist:
            return None

    @sync_to_async
    def save_state(self, match, state):
        if state["status"] == "finished" and match.status != "finished":
            self.process_match_end_sync(match, state)
        match.state = state
        match.status = state["status"]
        match.save()

    def process_match_end_sync(self, match, state):
        if match.mode != 'ranked':
            return
            
        p1 = match.player1.profile
        p2 = match.player2.profile
        
        p1_state = state["players"][match.player1.username]
        p2_state = state["players"][match.player2.username]
        
        K = 32
        e1 = 1 / (1 + 10 ** ((p2.rating - p1.rating) / 400))
        e2 = 1 / (1 + 10 ** ((p1.rating - p2.rating) / 400))
        
        if p1_state["lives"] > 0 and p2_state["lives"] <= 0:
            s1, s2 = 1, 0
            p1.ranked_wins += 1
            p2.losses += 1
        elif p2_state["lives"] > 0 and p1_state["lives"] <= 0:
            s1, s2 = 0, 1
            p2.ranked_wins += 1
            p1.losses += 1
        else:
            s1, s2 = 0.5, 0.5
            
        p1.rating = int(p1.rating + K * (s1 - e1))
        p2.rating = int(p2.rating + K * (s2 - e2))
        
        p1.save()
        p2.save()

    @sync_to_async
    def handle_disconnect(self):
        try:
            match = Match.objects.get(id=self.match_id)
            if match.status == 'in_progress':
                if match.mode == 'casual':
                    match.status = 'finished'
                    match.save()
                    return True
        except Match.DoesNotExist:
            pass
        return False

    async def broadcast_state(self, state, event_type):
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'game_message',
                'event_type': event_type,
                'state': state
            }
        )

    async def game_message(self, event):
        await self.send(text_data=json.dumps({
            'event': event['event_type'],
            'state': event['state']
        }))
