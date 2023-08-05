volatile short* AUDIO_IN_BASE = (volatile short*) 0xFFFFFC00;
volatile char* AUDIO_FIFO_CTRL_REG = (volatile char*) 0xFFFFFC02;

#include <stdio.h>
#include <dev/io.h>

int main()
{
	/*int samplesSent = 0;
	long t0 = 0, t1 = 0;
	CSRR_READ(t0, 0xC00);*/
	
	//Sync with receiver
	char c = 0;
	while((c = getchar()) != 'z')
	{
		putchar(c);
	}
	
	while (1)
	{
		while (*AUDIO_FIFO_CTRL_REG & 1);
		
		
		short audioData = *AUDIO_IN_BASE;
		putchar(audioData);
		audioData >>= 8;
		putchar(audioData);
		/*samplesSent++;
		
		CSRR_READ(t1, 0xC00);
		if (t1 - t0 > 100000000)	// 1 second
		{
			CSRR_READ(t0, 0xC00);
			printf("Sent: %d\n", samplesSent);
			samplesSent = 0;
		}*/
	}
}