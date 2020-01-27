# -----------------------------------------------------------------------------
# pseudoFP.py
# generate pseudo fingerprint vectors (Length = L) for N patients
#
# by Jewel Y. Lee (jewel.yh.lee@gmail.com), updated on 8/31/18
# -----------------------------------------------------------------------------
import numpy as np

# User defined variables
N = 5                       # number of patients
L = 10                      # length of the fingerprint

# Generate random number as fp vectors (between -1 to 1)
np.random.seed(1)
fp = np.zeros((N, L))
for i in range(N):
    fp[i] = np.round(np.random.uniform(0, 1, size=L)-0.5, 3)

# Save fp to csv file, each row represents a patient's fp
np.savetxt("pseudoFP.csv", fp, delimiter=",", fmt='%1.3f')