#!/usr/bin/env python

# standard library
import copy
import os
import socket
import random
import time
import traceback

# common modules
from common.simple_logger import SimpleLogger
import common.utils

# project-related modules
from client import Client
from config import Config
from message import Message
from player import Player
from world import World


###########################
# Constants
###########################

PRODUCT_NAME = 'multiplayer_game_server'
PRODUCT_VERSION = 100
PROGRAM_PATH = os.path.dirname(os.path.abspath(__file__))
CONFIG_FILE_NAME = os.path.join(PROGRAM_PATH, 'config.ini')
LOGS_DIR = os.path.join(PROGRAM_PATH, 'logs')


###########################
# Global variables
###########################

logger = None
config = None
sock = None
clients = {}  # key: addr, value: Client
world_state = World(w=640, h=480)  # TODO: Add checks


###########################
# Methods
###########################

def init_logger():
  global logger

  logger = SimpleLogger(LOGS_DIR)


def print_header():
  header = common.utils.build_header(PRODUCT_NAME, PRODUCT_VERSION)
  for line in header.split('\n'):
    logger.info(line)


def load_config():
  global config

  config = Config()
  config.load(CONFIG_FILE_NAME)


def init_sock():
  global sock

  sock = socket.socket(socket.AF_INET,
                     socket.SOCK_DGRAM)
  sock.bind((config.ip_addr, config.port))
  sock.setblocking(0)


def debug_log(msg):
  if config.debug:
    logger.info(msg)


def send_message(msg, addr):
  # TODO: Think about it
  if msg['type'] == 'update':
    client = clients[addr]
    msg['id'] = client.send_seq_num
    client.send_seq_num += 1
    client.diffs[msg['id']] = msg['changes']

  msg = Message(msg)
  debug_log('[send/{addr}]: {msg}'.format(addr=addr, msg=msg.to_string()))
  sock.sendto(msg.to_string(), addr)


def broadcast_message(msg):
  for addr, _ in clients.iteritems():
    send_message(msg, addr)


def process_message(msg, addr):
  debug_log('[recv/{addr}]: {msg}'.format(addr=addr, msg=msg.to_string()))

  msg_type = msg.type
  if msg_type == 'ping':
    on_ping(msg.id, addr)
  elif msg_type == 'connect':
    on_connect(msg.name, addr)
  elif msg_type == 'disconnect':
    on_disconnect(addr)
  elif msg_type == 'ack':
    on_ack(msg.ack, addr)
  elif msg_type == 'rel':
    on_rel(msg.msgs, addr)
  else:
    debug_log('Unknown message received: {msg}'.format(msg=msg.to_string()))


def on_ping(id, addr):
  send_message({
    'type': 'pong',
    'id': id
  }, addr)


def on_connect(name, addr):
  player = world_state.get_player_by_addr(addr)
  if player is None:
    if world_state.get_player_by_name(name) is None:
      player = world_state.add_player(name, addr)
    else:
      send_message({
        'type': 'connect',
        'success': False,
        'reason': 'Name is already in use'
      }, addr)
      return
  send_message({
    'type': 'connect',
    'success': True,
    'player': player
  }, addr)


def on_disconnect(addr):
  del clients[addr]
  world_state.remove_player(addr)


def on_ack(ack_id, addr):
  client = clients[addr]
  if ack_id > client.last_ack:
    diff = client.diffs.get(ack_id)
    apply_state_diff(client.world_state, diff)
    client.diffs = { k:v for k,v in client.diffs.items() if k > ack_id }
    client.last_ack = ack_id


def on_rel(rels, addr):
  client = clients[addr]

  last_rel_id = -1

  for rel in rels:
    if rel['id'] != client.recv_seq_num:
      continue

    msg_type = rel['type']
    if msg_type == 'keypressed':
      on_keypressed(rel['key'], addr)
    elif msg_type == 'keyreleased':
      on_keyreleased(rel['key'], addr)

    client.recv_seq_num += 1

    if rel['id'] > last_rel_id:
      last_rel_id = rel['id']

  if last_rel_id != -1:
    send_ack(last_rel_id, addr)


def on_keypressed(key, addr):
  for player_id, player in world_state.players.iteritems():
    if player.addr == addr:
      player.keys_states[key] = True
      break


def on_keyreleased(key, addr):
  for player_id, player in world_state.players.iteritems():
    if player.addr == addr:
      player.keys_states[key] = False
      break


def send_ack(id, addr):
  send_message({
    'type': 'ack',
    'ack': id
  }, addr)


def receive_messages():
  msgs = []

  while True:
    try:
      data, addr = sock.recvfrom(65565)
    except socket.error:
      break
    msgs.append((Message.from_string(data), addr))

  return msgs


def check_connections():
  cur_time = time.time()
  clients_copy = copy.deepcopy(clients)  # To avoid "RuntimeError: dictionary changed size during iteration"
  for addr, client in clients_copy.iteritems():
    if cur_time - client.last_msg_time > 5:
      on_disconnect(addr)


def get_states_diff(player_state):
  diff = []

  # Find new / changed players
  for w_player_id, w_player in world_state.players.iteritems():
    p_player = player_state.get(w_player_id)
    if p_player is None or p_player != w_player:
      diff.append(w_player)

  # Find disconnected players
  for p_player_id, p_player in player_state.iteritems():
    if world_state.players.get(p_player_id) is None:
      remove_player = copy.deepcopy(p_player)
      remove_player.x = -1
      remove_player.y = -1
      diff.append(remove_player)

  return diff


def apply_state_diff(player_state, diff):
  for player in diff:
    if player.x == -1 or player.y == -1:
      del player_state[player.id]
    else:
      player_state[player.id] = copy.deepcopy(player)


def main():
  init_logger()

  print_header()

  logger.info('Loading config...')
  load_config()

  logger.info('Initializing socket...')
  init_sock()

  logger.info('Listening on {}:{}...'.format(config.ip_addr, config.port))

  prev_time = time.time()
  dt = 0.0
  while True:
    # Process incoming messages
    msgs = receive_messages()
    for (msg, addr) in msgs:
      # Check whether it's a new client
      if addr not in clients:
        clients[addr] = Client()
      # Touch it anyway to update last message time
      clients[addr].touch()

      process_message(msg, addr)

    # Check existing connections for timeouts
    check_connections()

    cur_time = time.time()
    dt += cur_time - prev_time
    prev_time = cur_time
    if dt > 0.03:
      # Apply physics
      for player_id, player in world_state.players.iteritems():
        speed = 50
        if player.keys_states['up']:
          player.y = player.y - speed * dt
        elif player.keys_states['down']:
          player.y = player.y + speed * dt
        elif player.keys_states['left']:
          player.x = player.x - speed * dt
        elif player.keys_states['right']:
          player.x = player.x + speed * dt

      # Send updates
      for addr, client in clients.iteritems():
        changes = get_states_diff(client.world_state)
        if len(changes) == 0:
          continue

        send_message({
          'type': 'update',
          'changes': changes
        }, addr)

      dt = 0.0


if __name__ == '__main__':
  try:
    main()
  except:
    logger.critical('ERROR. Traceback:\n{}'.format(traceback.format_exc()))

