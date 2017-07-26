# RBTV Alert script

Ein simples Script was sich in den Autostart Ordner kopiert und überprüft ob auf dem [Sendeplan](https://www.rocketbeans.tv/wochenplan/) eine Sendung ist die einen interessiert (Pen & Paper zum Beispiel).

### Konfiguration

Die Konfigurationsdatei (Config.ini) befindet sich hier: `C:\Users\%USERNAME%\AppData\Roaming\RBTV Alert\Config.ini`

#### Einstellungen

Die folgenen Einstellungen lassen sich machen

* AlertLiveOnly [True/False]: Wenn auf False gesetz wird das Script alle Wiederholungen ignorieren.
* AlertNames: Eine liste an shows für welche er ein Alert geben soll. Mehrer Einträge sind mit einem Komma zu trennen.
* DateDiff: Die maximale Anzahl an Tagen die das Script im Vorraus informieren soll. Wird der Wert auf 0 gesetzt wird die Vorgabe ignoriert und immer alamiert.
* UseSSL [True/False]: Nutze eine SSL Verbindung (Port 443) stat einer HTTP Verbindung (Port 80).
* CheckForUpdate [True/False]: Überprüf beim start ob eine neuere Version vorhanden ist.
* AutoUpdate [True/False]: Wenn ein Update verfügbar ist, ob dieses automatisch installiert werden soll.
