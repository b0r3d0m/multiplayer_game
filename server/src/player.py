class Player:
  def __init__(self, id, name, x, y, addr):
    self.id = id
    self.name = name
    self.x = x
    self.y = y
    self.addr = addr
    self.keys_states = {
      'up': False,
      'down': False,
      'left': False,
      'right': False
    }

  def __eq__(self, other): 
    return self.__dict__ == other.__dict__

  def __ne__(self, other): 
    return self.__dict__ != other.__dict__

