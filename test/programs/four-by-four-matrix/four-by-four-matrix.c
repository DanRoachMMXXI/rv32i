#ifdef DEBUG
#include <stdio.h>
#endif

int uimult(unsigned int, unsigned int);

int main() {
	unsigned int a[4][4];
	unsigned int b[4][4];
	unsigned int c[4][4];

	for (int i = 0; i < 16; i++) {
		a[i/4][i%4] = i;
		b[i/4][i%4] = i+16;
	}

	for (int i = 0; i < 4; i++) {
		for (int j = 0; j < 4; j++) {
			int sum = 0;
			for (int k = 0; k < 4; k++)
				sum += uimult(a[i][k], b[k][j]);
			c[i][j] = sum;
		}
	}

#ifdef DEBUG
	printf("c = {\n");
	for (int i = 0; i < 4; i++)
		printf("\t{ %4d, %4d, %4d, %4d },\n", c[i][0], c[i][1], c[i][2], c[i][3]);
	printf("}\n");
#endif
}

int uimult(unsigned int a, unsigned int b) {
	int sum = 0;
	while (b--)
		sum += a;
	return sum;
}
