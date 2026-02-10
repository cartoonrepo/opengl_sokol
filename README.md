# Learn SOKOL
![Yotube Tutorial](screencaps/yt_tutorial.png)

1. Clone the repo:
  ```
  git clone --recurse-submodules git@github.com:cartoonrepo/opengl_sokol.git
  ```

2. Build the required static link libraries:
    ```
    1. navigate to sokol libs
    cd opengl_sokol/sokol-odin/sokol

    2. build libraries
    # on Linux:
    ./build_clibs_linux.sh
    # on Windows with MSVC (from a 'Visual Studio Developer Command Prompt')
    build_clibs_windows.cmd
    # on macOS:
    ./build_clibs_macos.sh

    3. back to project root
    cd ../../
    ```

3. Build and run the samples:
  odin run /path_to_source -debug -collection:sokol=sokol-odin/sokol
  ```
  odin run src/1_4_hello_triangle -debug -collection:sokol=sokol-odin/sokol
  ```
