import serial
import sys

s = serial.Serial('/dev/ttyUSB0', 2400)

clrs = [35,34]
c = 0

while True:
    b = s.read(1)
    if (b < b'\x20' or b >= b'\x7f') and b != b'\n':
        sys.stdout.write("\x1b[{:d}m{:02x}\x1b[0m".format(clrs[c],b[0]))
    else:
        sys.stdout.write(chr(int(b[0])))
    sys.stdout.flush()
    c = (c+1) & 1

