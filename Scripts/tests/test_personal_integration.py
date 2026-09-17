#!/usr/bin/env python3
"""Exercise personal overrides with private homes and mocked desktop commands."""
import os
import importlib.util
import io
import json
from contextlib import redirect_stdout
from unittest.mock import patch
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
LIB = ROOT / 'Configs/.local/lib/hyde'


class PersonalIntegration(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.env = dict(os.environ, HOME=str(self.root),
                        XDG_CONFIG_HOME=str(self.root / '.config'),
                        XDG_STATE_HOME=str(self.root / '.state'),
                        XDG_DATA_HOME=str(self.root / '.local/share'),
                        XDG_CACHE_HOME=str(self.root / '.cache'),
                        XDG_RUNTIME_DIR=str(self.root / '.run'),
                        PATH=str(self.bin) + ':' + os.environ['PATH'])

    def stub(self, name, body):
        path = self.bin / name
        path.write_text('#!/usr/bin/env bash\n' + body + '\n')
        path.chmod(0o755)

    def run_bash(self, source, check=True):
        return subprocess.run(['bash', '-c', source], env=self.env,
                              text=True, capture_output=True, check=check)

    def test_theme_font_precedence_and_fallback(self):
        text = (LIB / 'theme.switch.sh').read_text()
        function = re.search(r'^load_desktop_ui_variables\(\) \{.*?^\}',
                             text, re.M | re.S).group()
        result = self.run_bash(function + '''
FONT="Theme Font"; FONT_SIZE=9; MONOSPACE_FONT="Theme Mono"
DESKTOP_UI_FONT="Noto Sans"; DESKTOP_UI_FONT_SIZE=12
DESKTOP_UI_MONOSPACE_FONT="JetBrains Mono"
load_desktop_ui_variables
printf '%s|%s|%s\n' "$FONT" "$FONT_SIZE" "$MONOSPACE_FONT"
unset DESKTOP_UI_FONT DESKTOP_UI_FONT_SIZE DESKTOP_UI_MONOSPACE_FONT
FONT="Theme Fallback"; FONT_SIZE=10
load_desktop_ui_variables
printf '%s|%s\n' "$FONT" "$FONT_SIZE"
''')
        self.assertEqual(result.stdout.splitlines(),
                         ['Noto Sans|12|JetBrains Mono', 'Theme Fallback|10'])

    def test_colour_state_keeps_personal_fonts(self):
        self.stub('hyq', r"""case "$*" in
*FONT_SIZE*) printf '9' ;;
*FONT\[*) printf 'Theme' ;;
esac""")
        self.env.update(HYDE_SHELL_INIT='1', DESKTOP_UI_FONT='Noto Sans',
                        DESKTOP_UI_FONT_SIZE='12',
                        DESKTOP_UI_MONOSPACE_FONT='JetBrains Mono',
                        DESKTOP_UI_FONT_HINTING='slight')
        self.run_bash('get_hyprConf() { :; }; print_log() { :; }; source ' +
                      "'" + str(LIB / 'color/hypr.sh') + "'")
        state = self.root / '.state/hyde/lua_state/ui.lua'
        result = subprocess.run(['lua', '-e',
            'local s=dofile(os.getenv("TEST_UI_STATE")); print(s.ui.font); print(s.ui.font_size); '
            'print(s.ui.monospace_font); print(s.ui.font_hinting)'],
            env=dict(self.env, TEST_UI_STATE=str(state)), text=True, capture_output=True, check=True)
        self.assertEqual(result.stdout.splitlines(),
                         ['Noto Sans', '12', 'JetBrains Mono', 'slight'])

    def test_weather_backport_uses_location_clock(self):
        spec = importlib.util.spec_from_file_location('weather', LIB / 'weather.py')
        weather = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(weather)
        conditions = {'temp_C': '20', 'weatherCode': '113',
                      'weatherDesc': [{'value': 'Clear'}],
                      'localObsDateTime': '2026-10-11 07:00 AM'}
        day = {'date': '2026-10-11', 'maxtempC': '20', 'mintempC': '10',
               'astronomy': [{'sunrise': '07:00 AM', 'sunset': '07:00 PM'}],
               'hourly': [{'time': str(h * 100), 'tempC': '20',
                           'weatherCode': '113', 'weatherDesc': [{'value': 'Clear'}]}
                          for h in (0, 3, 6, 9, 12, 15, 18, 21)]}
        data = {'current_condition': [conditions], 'weather': [day]}
        for observed, expected in [('07:00 AM', [6, 9, 12, 15, 18, 21]),
                                   ('09:00 PM', [21])]:
            conditions['localObsDateTime'] = '2026-10-11 ' + observed
            output = io.StringIO()
            with patch.object(weather, 'get_weather_data', return_value=data), \
                 patch.dict(os.environ, {'WEATHER_SHOW_LOCATION': 'false',
                     'WEATHER_SHOW_TODAY_DETAILS': 'false', 'WEATHER_FORECAST_DAYS': '1',
                     'WEATHER_TIME_FORMAT': '24h', 'WEATHER_TEMPERATURE_UNIT': 'c'}), \
                 redirect_stdout(output):
                weather.main()
            tooltip = json.loads(output.getvalue())['tooltip']
            hours = [int(h) for h in re.findall(r'^(\d{1,2}) ', tooltip, re.M)]
            self.assertEqual(hours, expected)
        self.assertEqual(weather.get_location_hour({}, 10), 10)

    def test_logout_logical_size_and_missing_layout(self):
        launcher = self.root / 'logoutlaunch.sh'
        launcher.write_text((LIB / 'logoutlaunch.sh').read_text())
        (self.root / 'globalcontrol.sh').write_text(
            'HYDE_CACHE_HOME="$HOME/cache"\n'
            'enableWallDcol=1\n')
        layout = self.root / '.config/wlogout'
        layout.mkdir(parents=True)
        (layout / 'layout_1').write_text('{}')
        (layout / 'style_1.css').write_text('window { margin: ${mgn}px; }')
        self.stub('pgrep', 'exit 1')
        self.stub('hyprctl', '''printf '[{"focused":true,"width":3840,"height":2160,"scale":%s}]\n' "$TEST_SCALE"''')
        self.stub('wlogout', '''printf '%s|%s|%s\n' "$mgn" "$hvr" "$fntSize" > "$HOME/result"''')
        for scale, expected in [('1', '604|496|43'), ('2', '302|248|21'),
                                ('1.25', '483|397|34')]:
            self.env['TEST_SCALE'] = scale
            self.run_bash("bash '" + str(launcher) + "'")
            self.assertEqual((self.root / 'result').read_text().strip(), expected)
        (layout / 'layout_1').unlink()
        (self.root / 'result').unlink()
        result = self.run_bash("bash '" + str(launcher) + "'", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / 'result').exists())

    def test_aur_health_check_and_pacman_install(self):
        installer = self.root / 'install_aur.sh'
        installer.write_text((ROOT / 'Scripts/install_aur.sh').read_text())
        (self.root / 'global_fn.sh').write_text('''
aurhlpr=yay-bin
aurList=(yay-bin)
chk_list() { return 0; }
aur_health_check() { [[ "$TEST_HEALTHY" == 1 ]]; }
print_log() { :; }
use_default=--noconfirm
''')
        self.stub('pacman', '''printf '%s\n' "$*" >> "$HOME/pacman.log"
if [[ "$1" == -Si ]]; then exit "${TEST_MISSING:-0}"; fi''')
        self.stub('sudo', 'exec "$@"')
        self.env['TEST_HEALTHY'] = '1'
        self.run_bash("bash '" + str(installer) + "'")
        self.assertFalse((self.root / 'pacman.log').exists())
        self.env['TEST_HEALTHY'] = '0'
        self.run_bash("bash '" + str(installer) + "'")
        self.assertEqual((self.root / 'pacman.log').read_text().splitlines(),
                         ['-Si yay-bin', '--noconfirm -S yay-bin'])
        (self.root / 'pacman.log').unlink()
        self.env['TEST_MISSING'] = '1'
        result = self.run_bash("bash '" + str(installer) + "'", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.root / 'pacman.log').read_text().splitlines(),
                         ['-Si yay-bin'])


if __name__ == '__main__':
    unittest.main()
