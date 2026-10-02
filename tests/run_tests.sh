#!/usr/bin/env bash
# Lance les tests du jeu (scripts tests/test_*.gd) et affiche un résumé.
#   GODOT=/chemin/vers/godot tests/run_tests.sh            # tous les tests
#   GODOT=/chemin/vers/godot tests/run_tests.sh save story # quelques-uns
# Il faut l'éditeur Godot 4.7 et, sans écran, xvfb-run. Le projet doit avoir été importé une fois :
#   $GODOT --headless --editor --quit --path .
# Captures d'écran : tests/captures (ou $TEST_SHOTS) ; journaux : tests/logs.
cd "$(dirname "$0")/.." || exit 1
GODOT=${GODOT:-godot}
export TEST_SHOTS=${TEST_SHOTS:-$PWD/tests/captures}
# le monde se calcule d'un bloc au chargement (les tests attendent un nombre fixe d'images) ; test_boot vérifie l'écran de chargement
export SYNC_LOADING=${SYNC_LOADING:-1}
mkdir -p "$TEST_SHOTS" tests/logs
if [ $# -gt 0 ]; then list=("$@"); else list=($(ls tests/test_*.gd | sed 's#tests/test_##; s#\.gd$##')); fi
run=()
if [ -z "$DISPLAY" ] && command -v xvfb-run > /dev/null; then run=(xvfb-run -a -s "-screen 0 1280x720x24"); fi
ok=0; ko=0; bad=()
for t in "${list[@]}"; do
	log=tests/logs/$t.log
	timeout "${TEST_TIMEOUT:-600}" "${run[@]}" "$GODOT" --path . --resolution 1280x720 -s "$PWD/tests/test_$t.gd" > "$log" 2>&1
	res=$(grep -h "RÉSULTAT" "$log" | tail -1)
	err=$(grep -c "SCRIPT ERROR" "$log")
	fails=$(grep -c "  ÉCHEC  " "$log")
	if [[ "$res" == *"tout est bon"* ]] && [ "$err" -eq 0 ]; then
		ok=$((ok + 1)); printf "  OK     %-14s\n" "$t"
	else
		ko=$((ko + 1)); bad+=("$t"); printf "  ÉCHEC  %-14s %s (erreurs : %d, échecs : %d) -> %s\n" "$t" "${res:-pas de résultat}" "$err" "$fails" "$log"
		# ce qui a échoué, pour le lire directement dans le journal de la CI
		grep -h -m 4 -E "  ÉCHEC  |SCRIPT ERROR" "$log" | sed 's/^/           /'
	fi
done
echo "----"
echo "$ok test(s) réussi(s), $ko en échec${bad:+ : ${bad[*]}}"
[ "$ko" -eq 0 ]
