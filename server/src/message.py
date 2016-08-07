'''
We need both json and jsonpickle
because jsonpickle can natively encode nested Python objects
but is vulnerable to arbitrary code execution while standard json module isn't
'''

import json

import jsonpickle


class Message:
  def __init__(self, fields):
    self.fields = fields

    '''
    this is a little hack to be able to use Message objects
    as wrappers around dictionaries passed on theirs constructions
    e.g.
    msg = Message({'type': 'connect', 'name': 'player'})
    print(msg.type) -- connect
    '''
    for k, v in self.fields.iteritems():
      setattr(self, k, v)

  def to_string(self):
    return jsonpickle.encode(self.fields)

  @staticmethod
  def from_string(data):
    return Message(json.loads(data))

