from django.urls import path
from . import views

urlpatterns = [
    path('login/', views.simple_login),
    path('match/create/', views.create_match),
    path('match/join/', views.join_match),
]
