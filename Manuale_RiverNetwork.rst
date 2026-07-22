**RiverNetwork**

*RiverNetwork* è una classe Matlab che ricostruisce la topologia di un
reticolo idrografico, inteso come tutto il reticolo di un dato dominio
di interesse (anche comprendente più bacini indipendenti) a partire
dalle mappe delle idroderivate e permette alcune operazioni su di esso,
tra cui la corrispondenza ramo-ramo tra due rappresentazioni dello
stesso reticolo.

1. Guida rapida

1.1. Corrispondenza tra due reticoli

Partendo dai raster delle idroderivate di entrambi i domini, tipicamente
idraulico (es: *JRC.choice.txt*, *JRC.pnt.txt*, *JRC.area.txt*) e
idrologico (es: *IGAD_D1.choice.txt*, *IGAD_D1.pnt.txt*,
*IGAD_D1.area.txt*):

1. creazione dei due reticoli:

   *ReticoloIdraulico=RiverNetwork(struct('reticolo','JRC.choice.txt','puntatori','JRC.pnt.txt','aree_monte','JRC.area.txt','unita_misura_area','m2','codice_dominio',100000000));*

..

   *ReticoloIdrologico=RiverNetwork(struct('reticolo','IGAD_D1.choice.txt','puntatori','IGAD_D1.pnt.txt','aree_monte','IGAD_D1.area.txt','unita_misura_area','cells','codice_dominio',100000));*

2. calcolo della corrispondenza tra i due reticoli:

   ..

..

   *tabella_corrispondenze_rami=ReticoloIdraulico.corrispondezaReticoli(ReticoloIdrologico);*

Il calcolo scriverà nella directory corrente una tabella di
corrispondenza ramo-ramo, e 3 shape: reticolo idraulico (con i codici
dei rami idraulici e le corrispondenze), reticolo idrologico (con i
codici dei rami idrologici) e connettori tra i rami corrispondenti.

1.2. Generazione aree di competenza

Date le idroderivate (raster di puntatori e aree drenate) e una matrice
*sezioni* n x 2 con le coordinate:

   *mappa_aree_competenza=RiverNetwork.areeCompetenza('IGAD_D1.pnt.txt','IGAD_D1.area.txt*\ *',sezioni,[],[],’aree_competenza_IGAD_D1.tif’);*

..

..

..

..

**2. Manuale utente**

2.1. Struttura della classe

**RiverNetwork** è una classe che, una volta fornite le mappe delle
idroderivate in coordinate geografiche (reticolo, puntatori idrologici,
aree drenate), crea un oggetto con le seguenti property:

-  **nome_dominio** : stringa con il nome del dominio

-  **codice_dominio** : codice numerico del dominio

-  **rami** : struct con le informazioni dei rami (tratti di reticolo
      compresi tra due confluenze), contiene i seguenti campi:

   -  **codice**: codice del ramo (= codice del dominio + un
         progressivo, i rami sono ordinati per area drenata crescente)

   -  **coord**: coordinate del ramo

   -  **coord_from_node**: coordinate del from-node

   -  **coord_to_node**: coordinate del to-node

   -  **area_drenata_km2**: area drenata del ramo (del to-node) in
         km\ :sup:`2`

   -  **area_punti_km2**: area drenata di ogni punto del ramo in
         km\ :sup:`2`

   -  **bacino**: indice del bacino a cui appartiene il ramo (NON
         codice)

   -  **asta**: indice dell'asta a cui appartiene il ramo (NON codice)

   -  **Strahler**: ordine di Strahler del ramo

   -  **distanze_sorgente**: distanza dalla sorgente di ogni punto del
         ramo in km (lunghezza dell'asta fino a quel punto)

   -  **rami_monte**: indici dei rami a monte del ramo corrente (NON
         codici)

   -  **ramo_valle**: indice del ramo a valle del ramo corrente (NON
         codice)

-  **bacini** : struct con le informazioni dei bacini (insieme di rami
      connessi aventi come sezione di chiusura finale una foce),
      contiene i seguenti campi:

   -  **codice**: codice del bacino (= codice del dominio + un
         progressivo, i bacini sono ordinati per area crescente)

   -  **rami**: elenco dei rami del bacino (indici della struct rami,
         NON codici), i rami sono ordinati per area drenata crescente

   -  **aste**: elenco delle aste del bacino (indici della struct aste,
         NON codici), le aste sono ordinate per area drenata crescente

   -  **foce**: coordinate della foce

   -  **area_km**\ **2** : area del bacino in km\ :sup:`2`

   -  **coord_contorno** : coordinate del contorno del reticolo del
         bacino (poligono che passa per i punti più esterni del
         reticolo, NON lo spartiacque)

   -  **diametro** : diametro medio del bacino

   -  **centroide** : coordinate del centroide del bacino

-  **aste** : struct con le informazioni delle aste (sequenze di rami
      connessi costruite partendo da valle e scegliendo a ogni
      confluenza il ramo con area drenata maggiore), contiene i seguenti
      campi:

   -  **codice**: codice dell'asta (= codice del dominio + un
         progressivo)

   -  **rami**: sequenza ordinata dei rami dell'asta, da valle verso
         monte

   -  **coord**: coordinate dell'asta

   -  **area_drenata_km2**: area drenata dell'asta (=area drenata del
         punto più a valle) in km\ :sup:`2`

   -  **bacino**: indice del bacino a cui appartiene l'asta (NON codice)

   -  **distanze_sorgente**: distanza dalla sorgente di ogni punto
         dell'asta

La classe espone i seguenti metodi:

-  

   -  

      -  **RiverNewtork** (costruttore)

      -  **corrispondenzaReticoli** = calcola la corrispondenza ramo per
            ramo tra il reticolo corrente e un altro reticolo fornito in
            input

      -  **getSezioni** = estrae una sezione per ogni ramo, selezionata
            come quella più a valle che non corrisponda con una
            confluenza, se possibile

      -  **putSezioni** = date le coordinate di un insieme di sezioni,
            assegna ogni sezione al ramo più vicino avente l'area
            drenata (se specificata) più simile

      -  **isEqualTo** = verifica se due istanze **RiverNetwork** sono
            identiche

      -  **plotBacini** = plot dei contorni (non gli spartiacque) di
            tutti i bacini o di un loro sottoinsieme

      -  **plotReticolo** = plot del reticolo o di un sottoinsieme dei
            rami

      -  **mappa2Rami** = assegna a ogni ramo i valori estratti da una
            mappa

      -  **rami2Mappa** = genera una mappa sulla stessa griglia dei
            raster originali nella quale assegna un valore alle celle di
            ciascun ramo

      -  **tabellaCorrispondenza2Shape** = scrive gli shape risultato
            della corrispondenza a partire da una tabella di
            corrispondenza in input

      -  **writeReticoloShape** = scrive il reticolo su uno shapefile

      -  **areeCompetenza** = (metodo statico) genera la mappa delle
            aree di competenza a partire dalle mappe di puntatori e aree
            drenate e dalle coordinate di un insieme di sezioni

Per help generale della classe e del costruttore:

help RiverNetwork

Per help specifico di un metodo:

   *help RiverNetwork.<nome metodo>*

..

2.2. Creazione di un reticolo

2.2.1. Istanziazione

Per creare un oggetto:

   *Reticolo=RiverNetwork(input_RiverNetwork);*

..

dove **input_RiverNetwork** è una struct con i seguenti campi:

-  **reticolo**: nome del file raster (Geotiff .tif o ASCII grid
      .txt/.asc) o struct contenente il reticolo (1 = cella di reticolo,
      0/NaN = fuori dal reticolo) (campi: *mappa*, *x*, *y*)

-  **puntatori**: nome del file raster (Geotiff .tif o ASCII grid
      .txt/.asc) o struct contenente puntatori idrologici (NaN = fuori
      dal dominio) (campi: *mappa*, *x*, *y*)

-  **aree_monte**: nome del file raster (Geotiff .tif o ASCII grid
      .txt/.asc) o struct contenente l'area drenata in ogni cella (NaN =
      fuori dal dominio) (campi: *mappa*, *x*, *y*)

-  **correzioni** (OPZIONALE): nome del file shape di punti con le
      correzioni (deve contenere un campo "TIPO" con valori 1 o 2, se
      assente tutte le disconnessioni sono assunte di tipo 1) oppure una
      struct contenente le coordinate delle disconnessioni da applicare
      alla mappa del reticolo, con i seguenti campi (è necessario un
      record per ogni disconnessione):

   -  **coord_disconnessione**: vettore 1x2 [longitudine latitudine] del
         punto di disconnessione

   -  **tipo_disconnessione**: valori possibili = 1: elimina la cella
         dal reticolo, 2: elimina dal reticolo la cella e tutte le celle
         a valle fino alla foce

-  **unita_misura_area** (OPZIONALE): unità di misura delle aree nel
      raster delle aree a monte, possibili valori = *'cells'* : numero
      di celle (DEFAULT se non specificato), *'m2'* : metri quadrati,
      *'km2'* : chilometri quadrati

-  **nome_dominio** (OPZIONALE): stringa con il nome del dominio
      (=\ *'DOMINIO'* se non specificato)

-  **codice_dominio** (OPZIONALE): codice numerico del dominio (=0 se
      non specificato, è necessario differenziarlo tra diversi domini se
      si intendono calcolare corrispondenze tra reticoli, valore
      consigliato: intero*10^n, con n almeno un ordine di grandezza
      superiore al numero totale di rami, es.: reticolo con 1500 rami,
      codice dominio=10000, 20000, 30000,... o superiore). I rami, i
      bacini e le aste del reticolo avranno come codice codice_dominio +
      un progressivo

2.2.2. Correzioni

A volte è necessario correggere i raster originali delle idroderivate
introducendo delle disconnessioni nel reticolo. Questo si rende spesso
necessario quando si deve effettuare una corrispondenza tra due reticoli
e le topologie sono troppo diverse (caso tipico: bacino unico in un
reticolo che appare come bacini separati nell’altro).

Un esempio di incoerenza e relative disconnessioni:

|image1|

In figura sono rappresentati i contorni dei bacini (linee spesse) e i
reticoli (linee sottili) di parte di due reticoli che rappresentano la
stessa regione, uno in rosso, l’altro in blu. Il bacino rosso
orizzontale al centro della figura è un oggetto unico, ma interseca
parti di due bacini blu, disconnessi tra di loro. Per fare in modo che
la corrispondenza tra i due reticoli sia possibile, è necessario
introdurre delle disconnessioni, in entrambi i reticoli:

|image2|

In corrispondenza dei punti verdi il reticolo verrà disconnesso (in
questo caso tutte disconnessioni di tipo 1), in modo da ottenere la
seguente nuova configurazione dei bacini:

|image3|

In questi casi si deve fornire direttamente al costruttore nel campo
**’correzioni’** una struct con le coordinate e il tipo di
disconnessione (1: elimina la singola cella di reticolo, 2: elimina
tutto il tratto di fiume da quella cella fino alla foce) o un file shape
di punti con un campo “TIPO“ contenente il tipo di disconnessione (se
assente, viene assunto sempre il tipo “1”, che è quello più frequente).
La correzione elimina le celle di reticolo corrispondenti alla
disconnessione e modifica in maniera coerente le altre idroderivate (i
file originali rimangono invariati), dopodiché prosegue con la creazione
del reticolo.

Es:

..

   *Reticolo=RiverNetwork(struct('reticolo','zambesi.choice.txt','puntatori','zambesi.pnt.txt','aree_monte','zambesi.area.txt','unita_misura_area',’km2’,*\ ’nome_dominio’\ *,*\ ’zambesi’\ *,'codice_dominio',100000,*\ ’correzioni’\ *,*\ ’correzioni_zambesi.shp’\ *));*

Per l’help completo del costruttore:

help RiverNetwork

2.3. Corrispondenza tra reticoli

2.3.1. Calcolo della corrispondenza

Partendo da due rappresentazioni diverse della stessa regione di
interesse (es: da diversi fornitori di idroderivate, ottenuti da dem con
risoluzioni diverse, ecc.) è possibile produrre una corrispondenza
ramo-ramo di uno dei due reticoli verso l’altro.

Spesso le topologie di questi reticoli sono almeno in parte
significativamente diverse, per cui in generale una corrispondenza
perfetta NON È POSSIBILE. L’algoritmo cerca di ottenere la
corrispondenza migliore cercando di rispettare il più possibile la
coerenza idrologica, cioè facendo in modo che rami in sequenza vengano
assegnati a rami in sequenza, per evitare il più possibile
discontinuità.

La corrispondenza tra due reticoli NON è un’operazione simmetrica: dati
*Reticolo1* e *Reticolo2*, la chiamata

   tabella_corrispondenza12=Reticolo1.corrispondenzaReticoli(Reticolo2);

assegna a OGNI ramo del Reticolo 1 un ramo del Reticolo 2.
**tabella_corrispondenza12** è una matrice n x 2, in cui nella prima
colonna ci sono i codici di tutti i rami del Reticolo 1 e nella seconda
i corrispondenti codici dei rami del Reticolo 2. Vengono inoltre creati
un file di testo contenente la tabella, uno shape con il Reticolo 1 (e
la tabella di corrispondenza), uno con il Reticolo 2 e uno con i
connettori tra i due (segmenti che connettono ogni coppia di rami
corrispondenti).

Per i motivi citati la corrispondenza può non essere biunivoca né
completa, cioè a rami diversi del Reticolo 1 può essere assegnato uno
stesso ramo del Reticolo 2, e ci possono essere rami del Reticolo 2 non
assegnati a nessun ramo del Reticolo 1. In ogni caso tutti i rami del
Reticolo 1 riceveranno un corrispettivo del Reticolo 2. Ovviamente
l’operazione inversa:

   *tabella_corrispondenza21=Reticolo2.corrispondenzaReticoli(Reticolo1);*

..

darà in generale risultati diversi.

In caso di necessità di assegnare a ogni ramo di un reticolo idraulico
(cioè usato per generare mappe di inondazione) i valori di portata
(quantili, ecc.) ottenuti da simulazioni effettuate su un altro reticolo
(reticolo idrologico), l’assegnazione sarà quindi:

   tabella_corrispondenza=ReticoloIdraulico.corrispondenzaReticoli(ReticoloIdrologico);

Può avvenire che ci siano più reticoli da assegnare a un reticolo unico
(es: un reticolo idraulico su un’area molto grande, ma più reticoli
idrologici che, insieme, coprono la stessa area). In questo caso in
input al metodo deve essere fornito un cell array di tutti i reticoli,
es:

   tabella_corrispondenza=ReticoloIdraulico.corrispondenzaReticoli({ReticoloIdrologico1,
   ReticoloIdrologico2, ReticoloIdrologico3});

Il caso opposto, assegnazione di un singolo reticolo a reticoli
multipli, non è contemplato. Ovviamente per evitare ambiguità
nell’assegnazione, i codici di dominio dei reticoli idrologici devono
essere ben differenziati, come spiegato nel paragrafo 2.1.1.

Per l’help completo:

help RiverNetwork.corrispondenzaReticoli

**2.3.2. Algoritmo di corrispondenza**

Il calcolo della corrispondenza tra due reticoli è gerarchico: dagli
oggetti a più larga scala (domini) verso quelli a piccola scala (bacini
–> aste -> rami).

*Corrispondenza dei domini* (solo nel caso di reticoli multipli
assegnati a un reticolo): per ognuno dei Reticoli in input vengono
identificati i bacini del Reticolo 1 a cui verranno assegnati i bacini
corrispondenti, selezionandoli in base al fatto che la maggior parte
dell’area del bacino del Reticolo 1 sia contenuta entro il poligono del
contorno del Reticolo 2.

*Corrispondenza dei bacini:* a ogni bacino del Reticolo 1 viene
assegnato il bacino del Reticolo 2 che minimizza un funzionale
comprendente una distanza (tra le foci o tra i centroidi) e la
differenza tra le aree. In mancanza di bacini corrispondenti entro certe
tolleranze, viene assegnato il sottobacino nelle vicinanze di area più
simile (bacini “aggiuntivi”, chiusi cioè da rami non di foce). Se i
bacini si trovano al di sotto di una certa soglia di area, viene
eventualmente effettuata una rototraslazione rigida per massimizzare il
match geometrico. Una volta assegnate tutte le coppie di bacini,
all’interno di un dato bacino viene calcolata la corrispondenza delle
aste col bacino del Reticolo 2 assegnato.

*Corrispondenza delle aste:* partendo dall’asta principale, e
proseguendo per area drenata decrescente, per ogni asta del bacino 1,
vengono costruite dinamicamente le n (default = 10) aste ottenute
percorrendo sequenze di rami consecutivi del bacino 2 che iniziano dagli
n rami sorgente più vicini al ramo sorgente dell’asta corrente. Viene
poi selezionata l’asta che minimizza un funzionale che comprende la
distanza LRMSE e il confronto delle aree drenate. Si prosegue con tutte
le aste per area drenata decrescente. Una volta assegnate tutte le
coppie, all’interno di una data asta viene calcolata la corrispondenza
dei rami con l’asta del Reticolo 2 assegnata.

*Corrispondenza dei rami:* partendo dalla foce dell’asta e proseguendo
verso monte, a ogni ramo dell’asta 1 viene assegnato il ramo dell’asta 2
che minimizza un funzionale che comprende la distanza geometrica e la
differenza delle aree drenate.

L’algoritmo è costruito in modo da evitare il più possibile
discontinuità nell’assegnazione delle sequenze di rami e da evitare il
più possibile che assegnazioni indesiderate riguardino rami con area
drenata significativa.

**2.3.3. Parametri dell’algoritmo di corrispondenza**

È possibile modificare una serie di parametri dell’algoritmo di
corrispondenza, fornendo un input aggiuntivo alla chiamata:

   tabella_corrispondenza=ReticoloIdraulico.corrispondenzaReticoli(ReticoloIdrologico,
   parametri_corrispondenza);

Dove **parametri_corrispondenza** è una struct che può contenere uno o
più dei seguenti campi:

-  **Err_Max_Dist_Punti** : parametri per la modulazione della
      tolleranza sulle distanze tra punti [errore_minimo,
      errore_massimo, esponente]

-  **Err_Max_Area_Bacini** : parametri per la modulazione della
      tolleranza sulle differenze tra aree [errore_minimo,
      errore_massimo, esponente]

-  **Flag_Foci_Centroidi** : usa 1 = foci oppure 2 = centroidi per il
      calcolo della distanza tra bacini

-  **Pesi_Corrispondenza_Bacini** : pesi per la funzione di costo
      [peso_distanza, peso_aree]

-  **Pesi_Corrispondenza_Bacini_Aggiuntivi** : pesi per la funzione di
      costo [peso_distanza, peso_aree]

-  **Pesi_Corrispondenza_Aste** : pesi per la funzione di costo
      [peso_distanza,peso_aree]

-  **Pesi_Corrispondenza_Rami** : pesi per la funzione di costo
      [peso_distanza, peso_aree]

-  **Soglia_Area_Rototraslazione** : area massima di un bacino per
      applicare la rototraslazione nella corrispondenza di bacini
      [km\ :sup:`2`]

-  **N_Max_Aste_Esplorazione** : numero massimo di aste dinamiche da
      esplorare per la corrispondenza

-  **Flag_Bacini_Esclusi** : 1 = assegna tutti i bacini idraulici, anche
      fuori dal contorno del bacino idrologico, 0 = assegna solo i
      bacini idraulici che ricadono per la maggior parte all'interno del
      bacino idrologico

-  **Flag_Corrispondenza_Aste** : 1 = corrispondenza semplice con le
      aste standard, 2 = aste dinamiche (DEFAULT)

-  **Percorso_Output** : percorso in cui salvare i file di risultato
      (tabella di corrispondenza, shape dei reticoli, shape dei
      connettori)

Questi parametri possono modificare o distorcere molto il risultato
della corrispondenza, per cui è in generale meglio lasciare i valori di
default.

**2.3.4. Correzioni manuali**

Per effettuare correzioni manuali a posteriori alla corrispondenza si
può modificare direttamente la seconda colonna del file di testo della
tabella. Una volta ottenuta la tabella modificata, è possibile
riscrivere tutti i file shape in modo che tengano conto delle modifiche
alla corrispondenza nel seguente modo:

   *ReticoloIdraulico.tabellaCorrispondenza2Shape(ReticoloIdrologico,’tabella_corrispondenza_modificata.txt’,’./percorso_risultati_corrispondenza/’);*

..

Per l’help completo:

help RiverNetwork.tabellaCorrispondenza2Shape

2.4. Sezioni sul reticolo

È possibile inserire delle sezioni sul reticolo a partire da coordinate
note: l’algoritmo sposterà i punti in corrispondenza del punto di
reticolo più vicino o, se specificata, sul punto di reticolo più vicino
con area drenata più simile.

   sezioni=Reticolo.putSezioni(coordinate_sezioni);

Dove **coordinate_sezioni** è una matrice n x 2 o n x 3 che contiene
longitudine, latitudine ed eventualmente area drenata in km\ :sup:`2`. E
**sezioni** è una struct con campi **coord_sezione** e **codice_ramo**,
con il codice del ramo del reticolo al quale è stata assegnata la
sezione.

In alternativa è possibile far estrarre una sezione per ogni ramo, che
viene automaticamente inserita nel punto più a valle di ogni ramo che
non sia una confluenza (penultimo punto del ramo) quando possibile:

   *sezioni=Reticolo.getSezioni('sezioni_reticolo.shp');*

..

eventualmente scrivendo uno shape di punti *sezioni_reticolo.shp* con i
codici dei rami corrispondenti a ogni sezione. Per l’help completo:

*help RiverNetwork.putSezioni*

help RiverNetwork.getSezioni

**2.5. Generazione aree di competenza**

A partire dalle idroderivate (puntatori e area drenata) di un dato
dominio e un insieme di sezioni, è possibile generare la mappa delle
aree di competenza delle sezioni, cioè le aree di drenaggio diretto di
ogni sezione (area di competenza = area drenata dalla sezione escluse le
aree drenate da eventuali sezioni a monte della sezione data).

Per fare questo NON serve aver creato un reticolo, il calcolo viene
effettuato con un metodo statico:

..

   *mappa_aree_competenza=RiverNetwork.areecompetenza('zambesi.pnt.txt’,’zambesi.area.txt*\ *’,sezioni,[],[],’aree_competenza_zambesi’);*

dove **sezioni** è una matrice n x 2 con le coordinate delle sezioni o n
x 3 con le coordinate e i codici numerici da assegnare alle aree di
competenza. Avendo specificato anche un nome di file in uscita (ultimo
input), la mappa verrà scritta nel file *aree_competenza_zambesi.tif* .

Per generare la mappa delle aree di competenza di ogni ramo:

..

   *sezioni_rami=ReticoloZambesi.getSezioni;*

   *mappa_aree_competenza=RiverNetwork.areecompetenza('zambesi.pnt.txt’,’zambesi.area.txt*\ *’,[vertcat(sezioni_rami(:).coord_sezione),vertcat(sezioni_rami(:).codice_ramo)],[],[],’aree_competenza_zambesi’);*

..

Ovviamente in quest’ultimo caso le idroderivate devono essere
esattamente quelle utilizzate per la creazione di **ReticoloZambesi** .

Per l’help completo:

*help RiverNetwork.areeCompetenza*

**2.6. Corrispondenza tra sezioni idrologiche e aree di competenza
idrauliche**

2.6.1. Procedura generale

Per quanto detto nei paragrafi 2.3, 2.4 e 2.5, se è necessario
costruire, dato un dominio idraulico e un dominio idrologico, la
corrispondenza tra tutte le aree di competenza del dominio idraulico e
le sezioni dei rami idrologici, si procede come segue:

1. Dati necessari: idroderivate (reticolo, puntatori, aree drenate) del
      dominio idraulico e del dominio idrologico. Ad esempio, assumiamo
      di avere due domini per il fiume Zambesi, uno idraulico con le
      aree drenate misurate in km\ :sup:`2` e uno idrologico con le aree
      in celle, entrambi con circa 3000 rami. File delle idroderivate
      del dominio idrologico:

-  

   -  *zambesi_idrologico.choice.txt*

   -  *zambesi_idrologico.pnt.txt*

   -  *zambesi_idrologico.area.txt*

..

   File del dominio idraulico:

-  

   -  *zambesi_idraulico.choice.txt*

   -  zambesi_idraulico.pnt.txt

   -  zambesi_idraulico.area.txt

..

1. Creazione del reticolo idraulico:

   ..

..

   *ReticoloIdraulico=RiverNetwork(struct('reticolo','zambesi_idraulico.choice.txt','puntatori','zambesi_idraulico.pnt.txt','aree_monte','zambesi_idraulico.area.txt','unita_misura_area',’km2’,*\ ’nome_dominio’\ *,*\ ’zambesi_idraulico’\ *,'codice_dominio',100000));*

2. Estrazione delle sezioni di tutti i rami idraulici (le sezioni
      prendono i codici dei rami in cui sono inserite):

..

   *sezioni_rami_idraulici=ReticoloIdraulico.getSezioni;*

3. Generazione delle aree di competenza (scrive un raster
      aree_competenza_zambesi.tif):

   ..

..

   *RiverNetwork.areecompetenza('zambesi_idraulico.pnt.txt’,'zambesi_idraulico.area.txt’[vertcat(sezioni_rami_idraulici(:).coord_sezione),vertcat(sezioni_rami_idraulici(:).codice_ramo)],[],[],’aree_competenza_zambesi’);*

4. Creazione del reticolo idrologico:

   ..

..

   *ReticoloIdrologico=RiverNetwork(struct('reticolo','zambesi_idrologico.choice.txt','puntatori','zambesi_idrologico.pnt.txt','aree_monte','zambesi_idrologico.area.txt','unita_misura_area',’cells’,’nome_dominio’,’zambesi_idrologico’,'codice_dominio',10000));*

..

5. Estrazione delle sezioni di tutti i rami idrologici (le sezioni
      prendono i codici dei rami in cui sono inserite):

..

   *sezioni_rami_idrologici=ReticoloIdrologico.getSezioni;*

..

6. Corrispondenza tra i reticoli

..

   tabella_corrispondenza_areecomp_sezioni=ReticoloIdraulico.corrispondenzaReticoli(ReticoloIdrologico);

Alla fine vengono scritti la tabella di corrispondenza in un file
*Tabella_corrispondenza_rami\__zambesi_idraulico.txt*, che contiene una
tabella di questo tipo:

   *100001* *10002*

..

   *100002* *10001*

   *100003* *10004*

..

   *100004* *10010*

   *100005* *10005*

..

   *...*

(nella prima colonna ci sono i codici di tutti i rami idraulici e nella
seconda i codici dei corrispondenti rami idrologici), un file shape del
reticolo idraulico *Reticolo_idraulico\__zambesi_idraulico.shp*, che
contiene a sua volta la stessa identica tabella, uno shape del reticolo
idrologico *Reticolo_idrologico\__zambesi_idrologico.shp* e uno shape di
connettori *Connettori\__zambesi_idraulico\__zambesi_idrologico.shp*.

Avendo mantenuto coerenti i dati e i codici (le aree di competenza sono
state calcolate con le stesse idroderivate idrauliche e hanno ricevuto i
codici dei rami in cui sono state inserite le sezioni), alla fine il
file di testo con la tabella e la tabella degli attributi dello shape
con il reticolo idraulico contengono nella prima colonna i codici delle
aree di competenza, e nella seconda i codici delle sezioni idrologiche a
esse assegnate, ottenendo così la corrispondenza desiderata.

Nel caso di corrispondenza uno a molti (un dominio idraulico, molti
domini idrologici che coprono la stessa area), la parte della procedura
che riguarda i domini idrologici (punti 5 e 6) va ripetuta per ognuno,
tenendo presente la differenziazione dei codici dominio (vedi paragrafo
2.2.1), e il punto 7 va modificato fornendo in input un cell array con
tutti i domini idrologici (vedi paragrafo 2.3.1):

   tabella_corrispondenza_areecomp_sezioni=ReticoloIdraulico.corrispondenzaReticoli({ReticoloIdrologico1,ReticoloIdrologico2,ReticoloIdrologico3});

In questo caso vengono prodotti shape idrologici e shape di connettori
per ognuno dei domini idrologici, ma la tabella di corrispondenza sarà
sempre unica e comprenderà tutti i domini insieme.

2.6.2. Corrispondenza sezioni – aree di competenza entro una regione di
interesse

Nel caso sia richiesta questa corrispondenza entro una regione
specifica, ad esempio i confini di una nazione, NON eseguire la
procedura sulle idroderivate ritagliate sulla regione stessa: questo
altererebbe sia la topologia dei reticoli, sia le corrispondenze.

In generale, infatti, le sezioni idrologiche di interesse NON saranno
necessariamente tutte e sole quelle interne alla nazione, ma saranno
quelle dei rami idrologici assegnati alle aree di competenza idrauliche
che intersecano i confini nazionali (possono non coincidere e in alcuni
casi essere anche completamente esterne). Inoltre, ritagliare bacini
idrografici su confini amministrativi altererebbe la topologia e
distorcerebbe la procedura di corrispondenza.

In questo caso quindi la procedura da seguire è: per OGNI dominio
idraulico che interseca almeno parzialmente la nazione, ripetere tutta
la procedura del paragrafo 2.6.1 (eventualmente con corrispondenze con
domini idrologici multipli, se necessario), dopodiché le mappe di aree
di competenza andranno mosaicate e ritagliate sui confini nazionali. La
tabella di corrispondenza sarà quindi ottenuta unendo le tabelle
ottenute per ognuno dei domini idraulici, ed eventualmente filtrando i
codici delle aree di competenza non presenti nella mappa finale
ritagliata.

2.7. Altre funzioni

**2.7.1. Confronto di reticoli**

Per verificare che due Reticoli siano identici:

Reticolo1.isEqualTo(Reticolo2)

Per l’help completo:

*help RiverNetwork.isEqualTo*

2.7.2. Grafici

Per plottare il reticolo o un sottoinsieme dei rami usare il metodo
plotReticolo:

   *Reticolo.plotReticolo([],*\ ’b’\ *,2)*

plotta l’intero reticolo di colore blu e spessore 2 della linea.

Per plottare i contorni dei bacini (poligoni che passano per alcuni
punti del reticolo e seguono circa la forma generale del bacino), usare
il metodo plotBacini:

   *Reticolo.plotBacini([],*'r'*,3)*

..

plotta i contorni di tutti i bacini di colore rosso e spessore 3 della
linea.

Per l’help completo:

   help RiverNetwork.plotReticolo

..

   help RiverNetwork.plotBacini

2.7.3. Scrittura shape

Per scrivere il reticolo su un file shape:

*Reticolo.writeReticoloShape(‘reticolo.shp’,tabella_campi);*

Dove tabella_campi è un cell array contenente nella prima riga i nomi
dei campi e nelle righe successive i valori per ogni ramo.

Per l’help completo:

   help RiverNetwork.writeReticoloShape

2.7.4. Mappe

È possibile generare delle mappe raster del reticolo, assegnando un
valore per ramo:

   *Reticolo.rami2Mappa(valori_rami,’mappa_valori_rami.tif’)*

Assegna i valori in valori_rami (vettore numero_rami x 1) alle celle di
ogni ramo e poi scrive la mappa così ottenuta nel file
mappa_valori_rami.tif, sulla stessa griglia delle idroderivate originali
del reticolo.

È anche possibile ricavare valori da una mappa raster da assegnare a
ogni ramo o a ogni punto di ogni ramo:

   *valori_rami=Reticolo.mappa2Rami(‘mappa_raster.tif’);*

Per l’help completo:

   help RiverNetwork.rami2Mappa

..

   help RiverNetwork.mappa2Rami

.. |image1| image:: Pictures/10000000000002280000021B141D2F78.jpg
   :width: 8.301cm
   :height: 8.105cm
.. |image2| image:: Pictures/100000000000022A00000210FD096225.jpg
   :width: 8.447cm
   :height: 8.05cm
.. |image3| image:: Pictures/100000000000022A00000223A61589AD.jpg
   :width: 8.216cm
   :height: 8.112cm
