from django.db import models
from django.contrib.auth.models import User
import json

class PlayerProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profile')
    rating = models.IntegerField(default=1200)
    casual_wins = models.IntegerField(default=0)
    ranked_wins = models.IntegerField(default=0)
    losses = models.IntegerField(default=0)

    def __str__(self):
        return f"{self.user.username} (Elo: {self.rating})"

class Match(models.Model):
    STATUS_CHOICES = [
        ('waiting', 'Waiting'),
        ('in_progress', 'In Progress'),
        ('finished', 'Finished'),
    ]
    MODE_CHOICES = [
        ('casual', 'Casual'),
        ('ranked', 'Ranked'),
        ('private', 'Private'),
    ]

    player1 = models.ForeignKey(User, on_delete=models.CASCADE, related_name='matches_as_p1')
    player2 = models.ForeignKey(User, on_delete=models.CASCADE, related_name='matches_as_p2', null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='waiting')
    mode = models.CharField(max_length=20, choices=MODE_CHOICES, default='casual')
    join_code = models.CharField(max_length=10, blank=True, null=True)
    state = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Match {self.id} - {self.mode} - {self.status}"
