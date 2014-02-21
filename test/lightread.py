import serial

s = serial.Serial('/dev/ttyUSB0', 2400)

state = 0;
c0 = 0
c1 = 0
while True:
    b = ord(s.read(1))
    if state == 7:
        c1 = c1 + b*256
        print(c0, c1)
        state = 0
    elif state == 6:
        c1 = b
        state += 1
    elif state == 5:
        c0 = c0 + b*256
        state += 1
    elif state == 4:
        c0 = b
        state += 1
    elif state < 4 and b == 255:
        state += 1
    elif state < 2 and b == 0:
        state += 1
    else:
        state = 0
