import runpy
import sys

target = r'C:\Users\USUARIO\Documents\Claude\Projects\urbanizacion-toolkit\tools\\python\\bc3_tools.py'
if __name__ == '__main__':
    sys.argv = [target, *sys.argv[1:]]
    runpy.run_path(target, run_name='__main__')
