from rest_framework.decorators import api_view
from rest_framework.response import Response
from django.contrib.auth.models import User
from .models import Match, PlayerProfile
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync
import random
import string

def generate_join_code():
    return ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))

@api_view(['POST'])
def simple_login(request):
    username = request.data.get('username')
    if not username:
        return Response({'error': 'Username required'}, status=400)
    
    user, created = User.objects.get_or_create(username=username)
    profile, _ = PlayerProfile.objects.get_or_create(user=user)
    
    return Response({
        'username': user.username, 
        'user_id': user.id,
        'rating': profile.rating
    })

@api_view(['POST'])
def create_lobby(request):
    username = request.data.get('username')
    try:
        user = User.objects.get(username=username)
    except User.DoesNotExist:
        return Response({'error': 'User not found'}, status=404)
        
    code = generate_join_code()
    match = Match.objects.create(player1=user, mode='private', join_code=code)
    return Response({'match_id': match.id, 'status': match.status, 'join_code': code})

@api_view(['POST'])
def join_lobby(request):
    username = request.data.get('username')
    join_code = request.data.get('join_code')
    
    try:
        user = User.objects.get(username=username)
        match = Match.objects.get(join_code=join_code, status='waiting', mode='private')
    except (User.DoesNotExist, Match.DoesNotExist):
        return Response({'error': 'Invalid code or user'}, status=400)
        
    if match.player1 != user:
        match.player2 = user
        match.status = 'in_progress'
        match.save()
        return Response({'match_id': match.id, 'status': match.status})
    return Response({'error': 'Cannot join own match'}, status=400)

def _notify_player_joined(match_id):
    """Broadcast player_joined to the match's WebSocket group."""
    channel_layer = get_channel_layer()
    async_to_sync(channel_layer.group_send)(
        f'match_{match_id}',
        {'type': 'game_message', 'event_type': 'player_joined', 'state': {}}
    )

@api_view(['POST'])
def find_match(request):
    username = request.data.get('username')
    mode = request.data.get('mode', 'casual')
    
    try:
        user = User.objects.get(username=username)
    except User.DoesNotExist:
        return Response({'error': 'User not found'}, status=404)
        
    waiting_matches = Match.objects.filter(status='waiting', mode=mode).exclude(player1=user)
    
    if mode == 'ranked':
        profile = user.profile
        for m in waiting_matches:
            if abs(m.player1.profile.rating - profile.rating) <= 200:
                m.player2 = user
                m.status = 'in_progress'
                m.save()
                print(f"[HTTP] Ranked Match Found: {m.id} for {username}")
                _notify_player_joined(m.id)
                return Response({'match_id': m.id, 'status': m.status})
        
        match = Match.objects.create(player1=user, mode='ranked')
        print(f"[HTTP] Ranked Match Created: {match.id} for {username}")
        return Response({'match_id': match.id, 'status': match.status})
    else:
        match = waiting_matches.first()
        if match:
            match.player2 = user
            match.status = 'in_progress'
            match.save()
            print(f"[HTTP] Casual Match Found: {match.id} for {username}")
            _notify_player_joined(match.id)
            return Response({'match_id': match.id, 'status': match.status})
        
        match = Match.objects.create(player1=user, mode='casual')
        print(f"[HTTP] Casual Match Created: {match.id} for {username}")
        return Response({'match_id': match.id, 'status': match.status})

@api_view(['GET'])
def match_status(request, match_id):
    try:
        match = Match.objects.get(id=match_id)
        return Response({
            'status': match.status,
            'has_state': bool(match.state and 'players' in match.state)
        })
    except Match.DoesNotExist:
        return Response({'error': 'Match not found'}, status=404)
