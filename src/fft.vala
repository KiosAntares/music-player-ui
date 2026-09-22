// In-place radix-2 Cooley-Tukey FFT.
//
// Hand-rolled rather than linking fftw3: at the sizes the visualiser uses this
// costs well under a millisecond per frame even on the Orange Pi's A72 cores,
// and it keeps the dependency list (and the cross-distro packaging story) as
// small as the rest of this project tries to be.
namespace Fft {

    public class Plan {
        public int size { get; private set; }

        private int[] reverse;      // bit-reversal permutation
        private double[] tw_cos;    // twiddle factors, cos(2*pi*k/size)
        private double[] tw_sin;    // twiddle factors, sin(2*pi*k/size)

        public Plan (int size) {
            assert (size >= 2);

            int bits = 0;
            while ((1 << bits) < size)
                bits++;
            assert ((1 << bits) == size);   // radix-2 only

            this.size = size;

            reverse = new int[size];
            for (int i = 0; i < size; i++) {
                int r = 0;
                for (int b = 0; b < bits; b++) {
                    if ((i & (1 << b)) != 0)
                        r |= 1 << (bits - 1 - b);
                }
                reverse[i] = r;
            }

            tw_cos = new double[size / 2];
            tw_sin = new double[size / 2];
            for (int k = 0; k < size / 2; k++) {
                tw_cos[k] = Math.cos (2.0 * Math.PI * k / size);
                tw_sin[k] = Math.sin (2.0 * Math.PI * k / size);
            }
        }

        // Forward transform, in place. `re`/`im` must both be `size` long; for
        // real input, fill `im` with zeroes.
        public void forward (double[] re, double[] im) {
            assert (re.length == size && im.length == size);

            for (int i = 0; i < size; i++) {
                int j = reverse[i];
                if (j > i) {
                    double tr = re[i]; re[i] = re[j]; re[j] = tr;
                    double ti = im[i]; im[i] = im[j]; im[j] = ti;
                }
            }

            for (int len = 2; len <= size; len <<= 1) {
                int half = len >> 1;
                int step = size / len;       // stride into the twiddle tables
                for (int start = 0; start < size; start += len) {
                    int k = 0;
                    for (int j = 0; j < half; j++) {
                        // w = e^(-2*pi*i*k/size)
                        double wr = tw_cos[k];
                        double wi = -tw_sin[k];

                        int a = start + j;
                        int b = a + half;

                        double tr = re[b] * wr - im[b] * wi;
                        double ti = re[b] * wi + im[b] * wr;

                        re[b] = re[a] - tr;
                        im[b] = im[a] - ti;
                        re[a] += tr;
                        im[a] += ti;

                        k += step;
                    }
                }
            }
        }
    }
}
