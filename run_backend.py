import os
import sys

# Guarantee D:\krishisetu is always on Python path for both main process and uvicorn worker subprocesses
ROOT_DIR = os.path.dirname(os.path.abspath(__file__))
if ROOT_DIR not in sys.path:
    sys.path.insert(0, ROOT_DIR)
os.environ["PYTHONPATH"] = ROOT_DIR

if __name__ == "__main__":
    import uvicorn
    print(f"[*] Starting KrishiSetu Backend from {ROOT_DIR}...")
    uvicorn.run("backend.main:app", host="0.0.0.0", port=8000, reload=True)
