import time


class Client:
  def __init__(self):
    self.world_state = {}
    self.send_seq_num = 0
    self.recv_seq_num = 0
    self.last_ack = -1
    self.diffs = {}  # sent diffs (to apply it to the player's state later). key: id, value: list of updated objects. TODO: Remove old entries

  def touch(self):
    self.last_msg_time = time.time()

