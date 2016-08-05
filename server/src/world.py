# standard library
import random

# project-related modules
from player import Player


class World:
  def __init__(self, w, h):
    self.w = w
    self.h = h
    self.players = {}
    self.next_player_id = 0

  def add_player(self, name, addr):
    x = random.randint(0, self.w)
    y = random.randint(0, self.h)
    new_player = Player(self.next_player_id, name, x, y, addr)
    self.players[self.next_player_id] = new_player
    self.next_player_id += 1
    return new_player

  def remove_player(self, addr):
    self.players = {k: v for k, v in self.players.iteritems() if v.addr != addr}

  def get_player_by_addr(self, addr):
    for player_id, player in self.players.iteritems():
      if player.addr == addr:
        return player
    return None

  def get_player_by_name(self, name):
    for player_id, player in self.players.iteritems():
      if player.name == name:
        return player
    return None

