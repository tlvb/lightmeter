import serial

s = serial.Serial('/dev/ttyUSB0', 2400)

state = 0;
c0 = 0
c1 = 0
q = 0
while True:
    b = ord(s.read(1))
    if state == 9:
        q = q + b*256
        print("c0 {:04x}, c1 {:04x}, c1/c0 {:04x}".format(c0, c1, q));
        state = -1
    elif state == 8:
        q = b;
    elif state == 7:
        c1 = c1 + b*256
    elif state == 6:
        c1 = b
    elif state == 5:
        c0 = c0 + b*256
    elif state == 4:
        c0 = b
    elif state < 4 and b == 255:
        pass
    elif state < 2 and b == 0:
        pass
    else:
        state = -1
    state += 1
