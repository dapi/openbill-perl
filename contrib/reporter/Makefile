
CC=gcc
CFLAGS=-Wall -W -O3 -g -I. -I./includes 
LDFLAGS=

reprter: radix.o reporter.c
	${CC} $(CFLAGS) $(LDFLAGS) reporter.c -o reporter radix.o

radix.o: radix.h radix.c
	${CC} $(CFLAGS) -c radix.c


