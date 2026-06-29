// factorial.c
// Computes the factorial of 5 (120) and stores it in memory
int main() {
    int val = 5;
    int fact = 1;
    while (val > 0) {
        fact = fact * val;
        val = val - 1;
    }
    return fact;
}
