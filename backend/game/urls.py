from django.urls import path
from . import views

urlpatterns = [
    path('login/', views.simple_login),
    path('match/find/', views.find_match),
    path('lobby/create/', views.create_lobby),
    path('lobby/join/', views.join_lobby),
]
