"""Minimal serial terminal for the UART echo design.

Every key you type is sent to the board; every byte the board sends back is
printed as `char` (and hex for non-printable bytes). Ctrl-C or Ctrl-] quits.

    .venv/bin/python scripts/uart_term.py                 # auto-detect port
    .venv/bin/python scripts/uart_term.py /dev/cu.usbserial-XXXX1
"""

import glob
import os
import sys
import termios
import threading
import tty

import serial

BAUD = 115200
QUIT_KEYS = (b"\x03", b"\x1d")  # Ctrl-C, Ctrl-]


def find_port():
    ports = sorted(glob.glob("/dev/cu.usbserial-*1"))  # iCEBreaker UART = 2nd FTDI channel
    if not ports:
        sys.exit("No /dev/cu.usbserial-*1 port found. Is the board plugged in?")
    return ports[0]


def reader(port, stop):
    while not stop.is_set():
        data = port.read(64)
        for b in data:
            ch = chr(b)
            text = ch if ch.isprintable() else f"<{b:02x}>"
            os.write(sys.stdout.fileno(), f"[rx {text}]".encode())


def main():
    name = sys.argv[1] if len(sys.argv) > 1 else find_port()
    port = serial.Serial(name, BAUD, parity=serial.PARITY_EVEN, timeout=0.1)
    print(f"Connected to {name} at {BAUD} 8E1. Type to send, Ctrl-C to quit.\r")

    stop = threading.Event()
    thread = threading.Thread(target=reader, args=(port, stop), daemon=True)
    thread.start()

    fd = sys.stdin.fileno()
    old = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        while True:
            key = os.read(fd, 1)
            if key in QUIT_KEYS:
                break
            port.write(key)
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old)
        stop.set()
        thread.join()
        port.close()
        print("\nDisconnected.")


if __name__ == "__main__":
    main()
