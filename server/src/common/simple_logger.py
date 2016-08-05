import logging
import logging.handlers
import os


class LogFormatter(logging.Formatter):
    info_fmt = '%(levelname)-4.4s|%(asctime)s| %(message)s'
    warn_fmt = info_fmt
    err_fmt = '%(levelname)-4.4s|%(asctime)s|%(module)s|%(funcName)s|%(lineno)d %(message)s'
    crit_fmt = err_fmt

    def __init__(self, fmt='%(levelname)-4.4s|%(msg)s'):
        logging.Formatter.__init__(self, fmt)

    def format(self, record):
        # Save the original format configured by the user
        # when the logger formatter was instantiated
        format_orig = self._fmt

        # Replace the original format with one customized by logging level
        if record.levelno == logging.INFO:
            self._fmt = LogFormatter.info_fmt

        elif record.levelno == logging.WARNING:
            self._fmt = LogFormatter.warn_fmt

        elif record.levelno == logging.ERROR:
            self._fmt = LogFormatter.err_fmt

        elif record.levelno == logging.CRITICAL:
            self._fmt = LogFormatter.crit_fmt

        # Call the original formatter class to do the grunt work
        result = logging.Formatter.format(self, record)

        # Restore the original format configured by the user
        self._fmt = format_orig

        return result


class SimpleLogger:
    def __init__(self, logs_dir):
        if not os.path.exists(logs_dir):
            os.makedirs(logs_dir)

        self.root_logger = logging.getLogger(__name__)

        self.root_logger.setLevel(logging.INFO)

        fh = logging.handlers.TimedRotatingFileHandler(os.path.join(logs_dir, 'log_'), when='midnight')
        fh.setFormatter(LogFormatter())
        self.root_logger.addHandler(fh)

        ch = logging.StreamHandler()
        ch.setFormatter(LogFormatter())
        self.root_logger.addHandler(ch)

    def info(self, msg):
        self.root_logger.info(msg)

    def warning(self, msg):
        self.root_logger.warning(msg)

    def error(self, msg):
        self.root_logger.error(msg)

    def critical(self, msg):
        self.root_logger.critical(msg)
