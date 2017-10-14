# RBTV Alert script

Ein simples Script was sich in den Autostart Ordner kopiert und überprüft ob auf dem [Sendeplan](https://www.rocketbeans.tv/wochenplan/) eine Sendung ist die einen interessiert (Pen & Paper zum Beispiel). Die neuste Version kann [hier](https://www.github.com/CppAndre/RBTV-Alert/releases/latest) gefunden werden.

### Datein

Das Script selber kopiert sich hier hin: `%AppData%\Microsoft\Windows\Start Menu\Programs\Startup\RBTV Alert.exe`

Die Konfigurationsdatei (Config.ini) befindet sich hier: `%AppData\RBTV Alert\Config.ini`

Die Log und Crashdumps befinden sich im selben Ordner wie die Config.ini: `%AppData\RBTV Alert`

#### Einstellungen

Die folgenen Einstellungen lassen sich in der Konfigurationsdatei machen.
Die Konfigurationsdatei benutzt das sogennante [Ini-Format](https://de.wikipedia.org/wiki/Initialisierungsdatei#Aufbau).

* AlertLiveOnly [True/False]: Wenn auf True gesetz wird das Script alle Wiederholungen ignorieren.
* AlertNames: Eine liste an shows für welche er ein Alert geben soll. Mehrer Einträge sind mit einem Komma zu trennen.
* DateDiff: Die maximale Anzahl an Tagen die das Script im Vorraus informieren soll. Wird der Wert auf 0 gesetzt wird die Vorgabe ignoriert und immer alamiert.
* UseSSL [True/False]: Nutze eine SSL Verbindung (Port 443) statt einer HTTP Verbindung (Port 80).
* CheckForUpdate [True/False]: Überprüf beim start ob eine neuere Version vorhanden ist.
* AutoUpdate [True/False]: Wenn ein Update verfügbar ist, ob dieses automatisch installiert werden soll.
