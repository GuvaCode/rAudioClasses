CFLAGS = -Wall -fPIC
LDFLAGS = -lm

CC = gcc
TARGET = libhvl.so.1.9.0

all: $(TARGET)

$(TARGET): replay.o
	$(CC) -shared -o $@ $< $(LDFLAGS)

replay.o: replay.c
	$(CC) $(CFLAGS) -c $<

clean:
	rm -f *.o $(TARGET)

