import ctypes
import os
import time


libc = ctypes.CDLL(None)
libc.pthread_self.argtypes = []
libc.pthread_self.restype = ctypes.c_void_p
libc.pthread_get_stacksize_np.argtypes = [ctypes.c_void_p]
libc.pthread_get_stacksize_np.restype = ctypes.c_size_t

stack_bytes = int(libc.pthread_get_stacksize_np(libc.pthread_self()))
prefix = os.environ["STACK_PROBE_PREFIX"]
with open(f"{prefix}.stack.tmp", "w", encoding="utf-8") as output:
    output.write(str(stack_bytes))
os.replace(f"{prefix}.stack.tmp", f"{prefix}.stack")

# Let Dart print the measured stack before NumPy has a chance to crash the app.
for _ in range(100):
    if os.path.exists(f"{prefix}.ack"):
        break
    time.sleep(0.05)

try:
    import numpy as np

    result = np.array([1.0, 2.0, 3.0]) @ np.array([4.0, 5.0, 6.0])
    if result != 32.0:
        raise AssertionError(f"unexpected NumPy result: {result}")
    outcome = "ok"
except Exception as error:
    outcome = f"error:{type(error).__name__}:{error}"

with open(f"{prefix}.result.tmp", "w", encoding="utf-8") as output:
    output.write(f"stack_bytes={stack_bytes} numpy={outcome}\n")
os.replace(f"{prefix}.result.tmp", f"{prefix}.result")
