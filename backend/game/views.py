from rest_framework.decorators import api_view
from rest_framework.response import Response
from django.contrib.auth.models import User
from django.contrib.auth import authenticate, login
from .models import Match

@api_view(['POST'])
def simple_login(request):
    username = request.data.get('username')
    if not username:
        return Response({'error': 'Username required'}, status=400)
    
    # MVP: auto-create user if not exists
    user, created = User.objects.get_or_create(username=username)
    # Since we are not using passwords in this MVP, we will just simulate a login
    # For a real MVP, we should use tokens or actual sessions.
    # To keep it simple for the frontend, we just return the username.
    return Response({'username': user.username, 'user_id': user.id})

@api_view(['POST'])
def create_match(request):
    username = request.data.get('username')
    try:
        user = User.objects.get(username=username)
    except User.DoesNotExist:
        return Response({'error': 'User not found'}, status=404)
        
    match = Match.objects.create(player1=user)
    return Response({'match_id': match.id, 'status': match.status})

@api_view(['POST'])
def join_match(request):
    username = request.data.get('username')
    match_id = request.data.get('match_id')
    
    try:
        user = User.objects.get(username=username)
        match = Match.objects.get(id=match_id, status='waiting')
    except (User.DoesNotExist, Match.DoesNotExist):
        return Response({'error': 'Invalid match or user'}, status=400)
        
    if match.player1 != user:
        match.player2 = user
        match.status = 'in_progress'
        match.save()
        return Response({'match_id': match.id, 'status': match.status})
    return Response({'error': 'Cannot join own match'}, status=400)
