import ctypes
import os


libc = ctypes.CDLL(None)
libc.pthread_self.argtypes = []
libc.pthread_self.restype = ctypes.c_void_p
libc.pthread_get_stacksize_np.argtypes = [ctypes.c_void_p]
libc.pthread_get_stacksize_np.restype = ctypes.c_size_t

stack_bytes = int(libc.pthread_get_stacksize_np(libc.pthread_self()))
print(f"STACK_PROBE_STACK_BYTES: {stack_bytes}", flush=True)

try:
    import numpy as np

    result = np.array([1.0, 2.0, 3.0]) @ np.array([4.0, 5.0, 6.0])
    if result != 32.0:
        raise AssertionError(f"unexpected NumPy result: {result}")
    outcome = "ok"
except Exception as error:
    outcome = f"error:{type(error).__name__}:{error}"

with open(os.environ["STACK_PROBE_RESULT"], "w", encoding="utf-8") as output:
    output.write(f"stack_bytes={stack_bytes} numpy={outcome}\n")
