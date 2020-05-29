#!/bin/bash

# install depends
apt-get update; apt-get -y install python3-pip wget
pip3 install --upgrade --user pip setuptools virtualenv
python3 -m virtualenv /tmp/kivy_venv

wget -O /tmp/python3.7.AppImage https://github.com/niess/python-appimage/releases/download/python3.7/python3.7.7-cp37-cp37m-manylinux2014_x86_64.AppImage
chmod +x /tmp/python3.7.AppImage
/tmp/python3.7.AppImage --appimage-extract
mv squashfs-root /tmp/kivy_extracted

# copy depends that were installed with kivy into our kivy AppDir
rsync -a /tmp/kivy_venv/ /tmp/kivy_extracted/opt/python3.7

# add our code to the AppDir
cat > /tmp/kivy_extracted/opt/main.py <<'EOF'
import kivy
#kivy.require('1.0.6') # replace with your current kivy version !

from kivy.app import App
from kivy.uix.label import Label


class MyApp(App):

  def build(self):
    return Label(text='Hello world!')


if __name__ == '__main__':
  MyApp().run()
EOF

# change AppRun so it executes our app
mv /tmp/kivy_extracted/AppRun /tmp/kivy_extracted/AppRun.orig
cat > /tmp/kivy_extracted/AppRun <<'EOF'
#! /bin/bash

# Export APPRUN if running from an extracted image
self="$(readlink -f -- $0)"
here="${self%/*}"
APPDIR="${APPDIR:-${here}}"

# Export TCl/Tk
export TCL_LIBRARY="${APPDIR}/usr/share/tcltk/tcl8.5"
export TK_LIBRARY="${APPDIR}/usr/share/tcltk/tk8.5"
export TKPATH="${TK_LIBRARY}"

# Call the entry point
for opt in "$@"
do
    [ "${opt:0:1}" != "-" ] && break
    if [[ "${opt}" =~ "I" ]] || [[ "${opt}" =~ "E" ]]; then
        # Environment variables are disabled ($PYTHONHOME). Let's run in a safe
        # mode from the raw Python binary inside the AppImage
        "$APPDIR/opt/python3.7/bin/python3.7 $APPDIR/opt/main.py" "$@"
        exit "$?"
    fi
done

# Get the executable name, i.e. the AppImage or the python binary if running from an
# extracted image
executable="${APPDIR}/opt/python3.7/bin/python3.7 ${APPDIR}/opt/main.py"
if [[ "${ARGV0}" =~ "/" ]]; then
    executable="$(cd $(dirname ${ARGV0}) && pwd)/$(basename ${ARGV0})"
elif [[ "${ARGV0}" != "" ]]; then
    executable=$(which "${ARGV0}")
fi

# Wrap the call to Python in order to mimic a call from the source
# executable ($ARGV0), but potentially located outside of the Python
# install ($PYTHONHOME)
(PYTHONHOME="${APPDIR}/opt/python3.7" exec -a "${executable}" "$APPDIR/opt/python3.7/bin/python3.7" "$APPDIR/opt/main.py" "$@")
exit "$?"
EOF

# make it executable
chmod +x /tmp/kivy_extracted/AppRun

# create the AppImage from kivy AppDir
wget -O /tmp/appimagetool.AppImage https://github.com/AppImage/AppImageKit/releases/download/12/appimagetool-x86_64.AppImage
chmod +x /tmp/appimagetool.AppImage
/tmp/appimagetool.AppImage /tmp/kivy_extracted

