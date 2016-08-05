import ConfigParser


class Config:
    def __init__(self):
        pass

    def load(self, filename):
        config = ConfigParser.SafeConfigParser()
        config.read(filename)

        self.debug = bool(config.get('general', 'debug'))

        self.ip_addr = config.get('network', 'ip_addr')
        self.port = int(config.get('network', 'port'))

