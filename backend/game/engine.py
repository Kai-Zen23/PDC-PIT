import random

class GameEngine:
    @staticmethod
    def create_initial_state(p1_username, p2_username):
        return {
            "status": "in_progress",
            "current_turn": p1_username,
            "target_number": 21,
            "round": 1,
            "deck": [],
            "p1": p1_username,
            "p2": p2_username,
            "players": {
                p1_username: GameEngine._create_player_state(),
                p2_username: GameEngine._create_player_state()
            }
        }

    @staticmethod
    def _create_player_state():
        return {
            "lives": 3,
            "visible_cards": [],
            "hidden_cards": [],
            "powerups": [],
            "has_stood": False,
            "turns_taken": 0,
            "powerups_used_this_round": 0,
            "target_override_used": False
        }

    @staticmethod
    def start_round(state):
        state["deck"] = list(range(1, 12))
        random.shuffle(state["deck"])
        state["target_number"] = 21
        
        for p in state["players"].values():
            p["visible_cards"] = []
            p["hidden_cards"] = []
            p["has_stood"] = False
            p["turns_taken"] = 0
            p["powerups_used_this_round"] = 0
        
        # Power-ups assignment
        if state["round"] == 2 or state["round"] == 3:
            for p in state["players"].values():
                p["powerups"].extend(random.choices([1, 2, 3, 4, 5], k=2))
        
        # Deal cards
        for username, p in state["players"].items():
            while True:
                if len(state["deck"]) < 2:
                    state["deck"] = list(range(1, 12))
                    random.shuffle(state["deck"])
                p["visible_cards"] = [state["deck"].pop()]
                p["hidden_cards"] = [state["deck"].pop()]
                if sum(p["visible_cards"]) + sum(p["hidden_cards"]) <= state["target_number"]:
                    break
                    
        # Reset turn to p1 at start of round
        state["current_turn"] = state["p1"]
        return state

    @staticmethod
    def get_player_total(player_state):
        return sum(player_state["visible_cards"]) + sum(player_state["hidden_cards"])

    @staticmethod
    def switch_turn(state):
        state["current_turn"] = state["p2"] if state["current_turn"] == state["p1"] else state["p1"]
        if state["players"][state["current_turn"]]["has_stood"]:
             state["current_turn"] = state["p2"] if state["current_turn"] == state["p1"] else state["p1"]

    @staticmethod
    def check_round_end(state):
        p1_state = state["players"][state["p1"]]
        p2_state = state["players"][state["p2"]]
        
        p1_total = GameEngine.get_player_total(p1_state)
        p2_total = GameEngine.get_player_total(p2_state)
        
        p1_bust = p1_total > state["target_number"]
        p2_bust = p2_total > state["target_number"]
        
        both_stood = p1_state["has_stood"] and p2_state["has_stood"]
        deck_empty = len(state["deck"]) == 0
        
        if p1_bust or p2_bust or both_stood or deck_empty:
            return GameEngine._resolve_round(state, p1_total, p2_total, p1_bust, p2_bust)
        return state

    @staticmethod
    def _resolve_round(state, p1_total, p2_total, p1_bust, p2_bust):
        p1_state = state["players"][state["p1"]]
        p2_state = state["players"][state["p2"]]
        
        if p1_bust and not p2_bust:
            p1_state["lives"] -= 1
        elif p2_bust and not p1_bust:
            p2_state["lives"] -= 1
        elif p1_bust and p2_bust:
            # Both bust -> both lose life? Or draw? Let's say both lose life.
            p1_state["lives"] -= 1
            p2_state["lives"] -= 1
        else:
            diff1 = state["target_number"] - p1_total
            diff2 = state["target_number"] - p2_total
            if diff1 < diff2:
                p2_state["lives"] -= 1
            elif diff2 < diff1:
                p1_state["lives"] -= 1
                
        if p1_state["lives"] <= 0 or p2_state["lives"] <= 0:
            state["status"] = "finished"
        else:
            state["round"] += 1
            # In a full implementation, we wouldn't auto-start here to show round results.
            # But for MVP, we mark as waiting_for_next_round or just start it.
            # We will rely on the consumer to handle "round_end" event and then start the next round.
        return state
