import serial
import re
import time
import pyaudio

def streamToFile():
    t0 = time.time()

    print(t0)

    samples = 0
    while(True):
        a = s.read()      
        b = s.read()
        
        f.write(b)
        f.write(a)
        
        samples = samples + 1
        
        t1 = time.time()
        if (t1 - t0 >= 1.0):
            print(samples)
            samples = 0
            t0 = time.time()
        
def streamToAudioOut():
    CHUNK = 1024
    
    p = pyaudio.PyAudio()
    
    stream = p.open(
    rate=48000,
    channels=1,
    format=pyaudio.paInt16,
    output=True,
    frames_per_buffer=1024)
    
    samples = 0

    frames = bytes()
    while(True):
        a = s.read()
        b = s.read()
        c = a + b
        
        d = int.from_bytes(c)

        #print(d)
        
        if (d > 65535):
            d = 65535
        elif (d <= 0):
            d = 0

        frames = frames + d.to_bytes(2, 'big')

        samples = samples + 1
        
        if (samples == 1024):
            stream.write(frames, 1024)
            frames = bytes()
            samples = 0


s = serial.Serial('COM7', baudrate=2000000,timeout=1)
f = open("C:/users/pc/desktop/test.wav", "wb")

s.write(b'z')

#streamToFile()

p = pyaudio.PyAudio()
for i in range(p.get_device_count()):
    print(p.get_device_info_by_index(i))
    
streamToAudioOut()
    
    
