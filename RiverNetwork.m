classdef RiverNetwork
    
    % Reticolo=RiverNetwork(input_RiverNewtork)
    %
    % CLASSE RiverNetwork
    % Autore: Lorenzo Campo
    % Versione: 1.0.0
    %
    % Ricostruisce la struttura topologica di un reticolo fluviale a partire dai raster delle idroderivate (reticolo,
    % puntatori, aree drenate, i raster devono essere in coordinate geografiche lon-lat e non devono avere valori sui bordi)
    % del dominio di interesse e opera sul reticolo stesso. Un reticolo può in generale contenere più bacini, 
    % ogni bacino contiene uno o più rami, organizzati in aste. 
    % Può calcolare la corrispondenza tra due rappresentazioni dello stesso reticolo.
    %
    % INPUT COSTRUTTORE:
    %
    % input_RiverNewtork = struct con i seguenti campi:
    %                           reticolo: nome del file raster (Geotiff .tif o ASCII grid .txt/.asc) o struct con campi: 
    %                                         mappa : mappa del reticolo (1 = cella di reticolo, 0/NaN = fuori dal reticolo)
    %                                         x : vettore delle longitudini
    %                                         y : vettore delle longitudini
    %                           puntatori: nome del file raster (Geotiff .tif o ASCII grid .txt/.asc) o struct con campi: 
    %                                         mappa : mappa dei puntatori idrologici (NaN = fuori dal dominio)
    %                                         x : vettore delle longitudini
    %                                         y : vettore delle longitudini
    %                           aree_monte: nome del file raster (Geotiff .tif o ASCII grid .txt/.asc) o struct con campi: 
    %                                         mappa : mappa dell'area drenata in ogni cella (NaN = fuori dal dominio)
    %                                         x : vettore delle longitudini
    %                                         y : vettore delle longitudini
    %                           correzioni (OPZIONALE): nome del file shape con le correzioni (deve contenere un campo "TIPO" con valori 1 o 2, 
    %                                                   se assente tutte le disconnessioni soo assunte di tipo 1) oppure una struct contenente 
    %                                                   le coordinate delle disconnessioni da applicare alla mappa del reticolo, 
    %                                                   con i seguenti campi (è necessario un record per ogni disconnessione):
    %                                                       coord_disconnessione: vettore 1x2 [longitudine latitudine] del punto
    %                                                                             di disconnessione
    %                                                       tipo_disconnessione: valori possibili = 1 (elimina la cella dal reticolo),
    %                                                                                               2 (elimina dal reticolo la cella e
    %                                                                                                  tutte le celle a valle fino alla foce)
    %                           unita_misura_area (OPZIONALE): unità di misura delle aree nel raster delle aree a monte, possibili valori:
    %                                                               'cells' = numero di celle (DEFAULT se non specificato)
    %                                                               'm2' = metri quadrati
    %                                                               'km2' = chilometri quadrati
    %                           nome_dominio (OPZIONALE): stringa con il nome del dominio (="DOMINIO" se non specificato)
    %                           codice_dominio (OPZIONALE): codice numerico del dominio (=0 se non specificato, è necessario
    %                                                       differenziarlo tra diversi domini se si intedono calcolare
    %                                                       corrispondenze tra reticoli, valore consigliato: intero*10^n, 
    %                                                       con n almeno un ordine di grandezza superiore al numero totale di rami,
    %                                                       es: reticolo con 1500 rami, codice dominio=10000 o 100000 o superiore). 
    %                                                       I rami e i bacini del reticolo avranno come codice codice_domino + un progressivo
    %                           codici_puntatori (OPZIONALE, NON ATTIVO): matrice 3x3 con i codici delle direzioni di drenaggio coerenti con il raster puntatori.
    %                                                         DEFAULT se non specificato: [7 8 9
    %                                                                                      4 5 6
    %                                                                                      1 2 3];
    %
    % ES:
    %     % Correzioni da applicare ai raster
    %     correzioni_zambesi=struct('coord_disconnessione',[],'tipo_disconnessione',[]);
    %     correzioni_zambesi(1).coord_disconnessione=[33.34 -16.12];
    %     correzioni_zambesi(1).tipo_disconnessione=1;
    %     correzioni_zambesi(2).coord_disconnessione=[35.34 -16.70];
    %     correzioni_zambesi(2).tipo_disconnessione=1;
    %     % Struttura di Input
    %     input_RiverNetwork_Zambesi=struct('reticolo','reticolo_Zambesi.tif',...
    %                               'puntatori','puntatori_Zambesi.tif',...
    %                               'aree_monte','aree_monte_Zambesi.tif',...
    %                               'unita_misura_area','km2',...
    %                               'correzioni',correzioni_zambesi,...
    %                               'nome_dominio','Zambesi',...
    %                               'codice_dominio',100000);
    %     % Creazione del reticolo
    %     ReticoloZambesi=RiverNetwork(input_RiverNetwork_Zambesi);
    %
    %
    %
    % PROPERTY:
    %
    %   nome_dominio = stringa con il nome del dominio
    %   codice_dominio = codice numerico del dominio
    %   rami = struct con le informazioni dei rami (tratti di reticolo compresi tra due confluenze), contiene i seguenti campi:
    %               codice: codice del ramo (= codice del dominio + un progressivo, i rami sono ordinati per area drenata crescente)
    %               coord: coordinate del ramo
    %               coord_from_node: coordinate del from-node
    %               coord_to_node: coordinate del to-node
    %               area_drenata_km2: area drenata del ramo (del to-node) in km2
    %               area_punti_km2: area drenata di ogni punto del ramo in km2
    %               bacino: indice del bacino a cui appartiene il ramo (NON codice)
    %               asta: indice dell'asta a cui appartiene il ramo (NON codice)
    %               Strahler: ordine di Strahler del ramo
    %               distanze_sorgente: distanza dalla sorgente di ogni punto del ramo in km (lunghezza dell'asta fino a quel punto)
    %               rami_monte: indici dei rami a monte del ramo corrente (NON codici)
    %               ramo_valle: indice del ramo a valle del ramo corrente (NON codice)
    %   bacini = struct con le informazioni dei bacini (insieme di rami connessi aventi come sezione di chiusura finale una foce),
    %            contiene i seguenti campi:
    %                   codice: codice del bacino (= codice del dominio + un progressivo, i bacini sono ordinati per area crescente)
    %                   rami: elenco dei rami del bacino (indici della struct rami, NON codici), i rami sono ordinati per area
    %                         drenata crescente
    %                   aste: elenco delle aste del bacino (indici della struct aste, NON codici), le aste sono ordinate per area 
    %                         drenata crescente
    %                   foce: coordinate della foce
    %                   area_km2 : area del bacino in km2
    %                   coord_contorno : coordinate del contorno del reticolo del bacino (poligono che passa per i punti 
    %                                    più esterni del reticolo, NON lo spartiacque)
    %                   diametro : diametro medio del bacino
    %                   centroide : coordinate del centroide del bacino
    %   aste = struct con le informazioni delle aste (sequenze di rami connessi costruite partendo da valle e scegliendo
    %          a ogni confluenza il ramo con area drenata maggiore), contiene i seguenti campi:
    %               codice: codice dell'asta (= codice del dominio + progressivo)
    %               rami: sequenza ordinata dei rami dell'asta, da valle verso monte
    %               coord: coordinate dell'asta
    %               area_drenata_km2: area drenata dell'asta (=area drenata del punto più a valle) in km2
    %               bacino : indice del bacino a cui appartiene l'asta (NON codice)
    %               distanze_sorgente: distanza dalla sorgente di ogni punto dell'asta in km
    %
    %
    %
    % METODI ( per help specifico: help RiverNetwork.<nome metodo> ):
    %
    %  METODI DI ISTANZA:
    %   RiverNewtork (costruttore, vedi sopra)
    %   corrispondenzaReticoli = calcola la corrispondenza ramo per ramo tra il reticolo corrente e un altro reticolo fornito in input
    %   getSezioni = estrae una sezione per ogni ramo, selezionata come quella più a valle che non corrisponda con
    %                una confluenza, se possibile
    %   isEqualTo = verifica se due istanze RiverNetwork sono identiche
    %   mappa2Rami = assegna a ogni ramo i valori estratti da una mappa
    %   plotBacini = plot dei contorni (non gli spartiacque) di tutti i bacini o di un loro sottoinsieme
    %   plotReticolo = plot del reticolo o di un sottoinsieme dei rami
    %   putSezioni = date le coordinate di un insieme di sezioni, assegna ogni sezione al ramo più vicino avente l'area drenata
    %                (se specificata) più simile
    %   rami2Mappa = genera una mappa sulla stessa griglia dei raster originali nella quale assegna un valore alle celle di ciascun ramo
    %   tabellaCorrispondenza2Shape = scrive gli shape risultato della corrispondenza a partire da una tabella di corrispondenza in input
    %   writeReticoloShape = scrive il reticolo su uno shapefile
    %
    %  METODI STATICI:
    %   areeCompetenza = genera la mappa delle aree di competenza a partire dalle mappe di puntatori, aree drenate e le coordinate di un insieme di sezioni
    
    
    
    % Nomenclatura del codice:
    %   xxxx_xxxx = variabile  (snake case)
    %   xxxxXxxxx = metodo     (camel case)
    %   XxxxXxxxx = oggetto    (capital camel case)
    %   XXXX_XXXX = costante   (screaming snake case)
    %   Xxxx_Xxxx = parametro  (camel snake case)
    
    
    
    properties (SetAccess = immutable)
        
        nome_dominio
        codice_dominio
        rami
        bacini
        aste
        
    end
    
    properties (SetAccess = immutable, GetAccess = private)
        
        % variabili ausialiarie di calcolo
        VEC
        
    end
    properties (Access = private)
        
        % mappe
        nrows
        ncols
        ymedia
        x
        y
        dx
        dy
        area_cella
        
        % topologia
        topologia_raster
        
        % variabili ausialiarie di calcolo
        VEC_OP;
        topologia_raster_OP;
        
        % rami
        n_rami
        punti_centrali_rami;
        punti_centrali_rami_OP;
        rami_OP;          % COPIA operativa di rami, coordinate operative (modificabili)
        coord_rami_n_punti_interpolazione;
        coord_rami_n_punti_interpolazione_OP;
        
        % bacini
        n_bacini
        bacini_OP;        % COPIA operativa di bacini, estendibile
        matrice_confluenze_OP;
        aste_OP;
        coord_aste_bacini;
        coord_aste_n_punti_interpolazione;
        coord_aste_n_punti_interpolazione_OP;
        L_aste;
        aree_aste_bacini;
        
        % variabili di servizio
        x_vettori_radiali;
        y_vettori_radiali;
        
        % parametri tolleranze e corrispondenza reticoli
        Err_Max_Dist_Punti;
        Err_Max_Area_Bacini;
        Err_Max_Area_Bacini_Non_Assegnati;
        Pesi_Corrispondenza_Bacini;
        Pesi_Corrispondenza_Bacini_Aggiuntivi;
        Pesi_Corrispondenza_Aste;
        Pesi_Corrispondenza_Rami;
        Soglia_Area_Rototraslazione;
        Soglia_Distanza_Aste_Dinamiche;
        N_Max_Aste_Esplorazione;
        Flag_Bacini_Esclusi;
        Flag_Foci_Centroidi;
        Flag_Corrispondenza_Aste;
        Flag_Ricerca_Estesa;
        
        % Percorso di salvataggio dei risultati della corrispondenza
        Percorso_Output
        
    end
    
    properties (Constant, Access = private)
        
        n_punti_interpolazione=30;                      % numero di punti su cui vengono interpolati i rami
        PUNTATORI=[7 8 9                                % direzioni di drenaggio standard
                   4 5 6
                   1 2 3];
        
        % Flag valori di default per la corrispondenza
        AreeBacini_MinMax_err=[10  100000];             % aree dei bacini minime e massime [km^2] per definire la modulazione delle tolleranze
        ERRMAX_DIST_PUNTI=[1.5 2 10];                   % parametri per la massima tolleranza relativa per l'errore sui punti
        ERRMAX_AREA_BACINI=[1.5 2 5];                   % parametri per la massima tolleranza relativa per l'errore sulle aree
        ERRMAX_AREA_BACINI_NON_ASSEGNATI=0.5;           % percentuale di area massima di un bacino che deve trovarsi fuori dal contorno del reticolo per non essere considerato
        PESI_CORRISPONDENZA_BACINI=[2 1];               % [peso_distanza peso_aree]
        PESI_CORRISPONDENZA_BACINI_AGGIUNTIVI=[1 1];    % [peso_distanza peso_aree]
        PESI_CORRISPONDENZA_ASTE=[4 0];                 % [peso_distanza peso_aree]
        PESI_CORRISPONDENZA_RAMI=[4 0];                 % [peso_distanza peso_aree]
        SOGLIA_AREA_ROTOTRASLAZIONE=1000;               % soglia area massima [km2] per applicare rototraslazione ai bacini idrologici
        SOGLIA_DISTANZA_ASTE_DINAMICHE=50;              % soglia di distanza [km] per l'assegnazione delle aste idrologiche dinamiche
        N_MAX_ASTE_ESPLORAZIONE=10;                     % numero massimo di aste idrologiche dinamiche
        FLAG_BACINI_ESCLUSI=1;                          % 1 = assegna tutti i bacini idraulici, anche fuori dal boundary del bacino idrologico, 0 = assegna solo i bacini idraulici all'interno del bacino idrologico
        FLAG_FOCI_CENTROIDI=2;                          % 1 = foci, 2 = centroidi
        FLAG_RICERCA_ESTESA=1;                          % 1 = cerca i rami di testata evenatualmente anche fuori dal bacino,  0 = cerca i rami di testata solo tra i rami vicini del bacino
        FLAG_CORRISPONDENZA_ASTE=2;                     % 1 = corrispondenza semplice con le aste standard , 2 = aste dinamiche
                
    end
    
    
    
    methods
        
        
        function obj = RiverNetwork(input_RiverNetwork)
            
            % Costruttore:  obj = RiverNetwork(input_RiverNetwork)
            % "help RiverNetwork" per help dettagliato
                       
            
            
            % Controllo input
            if nargin==0 || isempty(input_RiverNetwork)
                disp(' ');
                disp('Input costruttore del tipo:')
                disp('input_RiverNetwork=struct(''reticolo'',[],''puntatori'',[],''aree_monte'',[],''longitudini'',[],''latitudini'',[],''correzioni'',[],''unita_misura_area'',[],''nome_dominio'',[],''codice_dominio'',[],''codici_puntatori'',[]);');                
                disp(' ');
                return
            end
            [input_RiverNetwork,flag_errore]=RiverNetwork.checkInput(input_RiverNetwork);
            if flag_errore==1
                obj=[];
                return
            end


            % Assegnazione input
            % Coordinate
            obj.x=input_RiverNetwork.longitudini;
            obj.y=input_RiverNetwork.latitudini;
            % Codice del dominio
            obj.codice_dominio=input_RiverNetwork.codice_dominio;
            % Nome del dominio
            obj.nome_dominio=input_RiverNetwork.nome_dominio;
            
            
            % Dimensioni raster
            [obj.nrows,obj.ncols]=size(input_RiverNetwork.reticolo);
            obj.x=obj.x(:)'; obj.y=obj.y(:)';
            
            % Dimensioni cella
            obj.dx=abs(obj.x(2)-obj.x(1)); obj.dy=abs(obj.y(2)-obj.y(1)); obj.ymedia=mean(obj.y);
            obj.area_cella=deg2km(obj.dx)*deg2km(obj.dy)*cos(abs(deg2rad(obj.ymedia)));
                        
            
            % Lettura correzioni del reticolo
            if isfield(input_RiverNetwork,'correzioni')==0
                input_RiverNetwork.correzioni=[];
            end
            if isempty(input_RiverNetwork.correzioni)==0
                if ischar(input_RiverNetwork.correzioni)
                    S=shaperead(input_RiverNetwork.correzioni);
                    ij_disconnessione_foce=num2cell(obj.coord2Indici([vertcat(S(:).X),vertcat(S(:).Y)]),2);
                    if isfield(S,'TIPO')==0
                        tipo_disconnessione=ones(size(ij_disconnessione_foce,1),1);
                    else
                        tipo_disconnessione=vertcat(S(:).TIPO);
                    end
                else
                    ij_disconnessione_foce=num2cell(obj.coord2Indici(vertcat(input_RiverNetwork.correzioni(:).coord_disconnessione)),2);
                    tipo_disconnessione=vertcat(input_RiverNetwork.correzioni(:).tipo_disconnessione);                    
                end
            else
                ij_disconnessione_foce=[];
            end
                        
            % Applicazione correzioni del reticolo
            if isempty(ij_disconnessione_foce)==0
                [input_RiverNetwork.reticolo,input_RiverNetwork.puntatori,input_RiverNetwork.aree_monte]=RiverNetwork.correzioneReticolo(ij_disconnessione_foce,input_RiverNetwork.reticolo,input_RiverNetwork.puntatori,input_RiverNetwork.aree_monte,tipo_disconnessione);
            end
            
            
            % Calcolo topologia del reticolo
            obj.topologia_raster=obj.topologia_reticolo(input_RiverNetwork.reticolo,input_RiverNetwork.puntatori,input_RiverNetwork.aree_monte,input_RiverNetwork.codici_puntatori);
            obj.topologia_raster_OP=obj.topologia_raster;
            

            % Calcolo delle aree a monte in km2
            input_RiverNetwork.aree_monte(input_RiverNetwork.aree_monte<0)=NaN;
            if strcmp(input_RiverNetwork.unita_misura_area,'cells')
                aree_monte_rami_km2=obj.topologia_raster.aree_monte_rami*obj.area_cella;
                aree_monte_km2=input_RiverNetwork.aree_monte*obj.area_cella;
            elseif strcmp(input_RiverNetwork.unita_misura_area,'m2')
                aree_monte_rami_km2=obj.topologia_raster.aree_monte_rami/1000000;
                aree_monte_km2=input_RiverNetwork.aree_monte/1000000;
            elseif strcmp(input_RiverNetwork.unita_misura_area,'km2')
                aree_monte_rami_km2=obj.topologia_raster.aree_monte_rami;
                aree_monte_km2=input_RiverNetwork.aree_monte;
            end
            
            
            % Strutture operative
            VEC=struct('coord_rami',[],'codici_rami',[],'aree_monte_rami_km2',[],'coord_to_node',[],'coord_foci',[],...
                       'aree_bacini_km2',[],'diametri_bacini',[],'centroidi_bacini',[]);
            
            
            % Rami
            obj.n_rami=length(obj.topologia_raster.indici_rami);                % numero totale di rami
            obj.rami=struct('codice',[],'coord',[],'coord_from_node',[],'coord_to_node',[],'area_drenata_km2',[],'area_punti_km2',[],'bacino',[],'asta',[],'distanze_sorgente',[],'Strahler',[],'rami_monte',[],'ramo_valle',[]);
            n_vettore_coord_rami=sum(cellfun(@length,obj.topologia_raster.indici_rami))+obj.n_rami;   % dimensione della matrice con le coordinate di tutti i punti di tutti i rami
            coord_rami=NaN(n_vettore_coord_rami,2);                             
            codici_rami=NaN(n_vettore_coord_rami,1);
            coord_from_node=obj.indici2coord(obj.topologia_raster.from_node);   % coordinate dei from-node
            coord_to_node=obj.indici2coord(obj.topologia_raster.to_node);       % coordinate dei to-node
            L=num2cell(cellfun(@length,obj.topologia_raster.rami_bacini));
            tabella_rami_bacini=[ [obj.topologia_raster.rami_bacini{:}]', cell2mat(cellfun(@(x,y) x*y, num2cell(1:length(L))', cellfun(@(x) ones(x,1) , L , 'UniformOutput',false) , 'UniformOutput' ,false) )];
            [~,indici_sort]=sort(tabella_rami_bacini(:,1));
            tabella_rami_bacini=tabella_rami_bacini(indici_sort,:);
            k=0;
            % ciclo sui rami
            for r=1:obj.n_rami
                obj.rami(r).codice=obj.codice_dominio+r;
                [i_ramo,j_ramo]=ind2sub([obj.nrows,obj.ncols],obj.topologia_raster.indici_rami{r});   % coordinate matrice delle celle del ramo
                obj.rami(r).coord=[obj.x(j_ramo)',obj.y(obj.nrows-i_ramo+1)'];                        % coordinate dei punti del ramo
                obj.rami(r).coord_from_node=coord_from_node(r,:);                                     % coordinate del from-node
                obj.rami(r).coord_to_node=coord_to_node(r,:);                                         % Coordinate del to-node
                obj.rami(r).area_drenata_km2=aree_monte_rami_km2(r);                                  % area drenata del ramo [km2]
                obj.rami(r).area_punti_km2=aree_monte_km2(obj.topologia_raster.indici_rami{r});       % area drenata in ogni punto del ramo [km2]
                obj.rami(r).bacino=tabella_rami_bacini(r,2);                                          % indice del bacino di appartenzenza del ramo
                coord_rami(k+1:k+length(i_ramo),:)=obj.rami(r).coord;                                 % matrice con le coordinate di tutti i punti di tutti i rami
                codici_rami(k+1:k+length(i_ramo)+1)=r;                                                % matrice con i codici rami per tutti i punti di tutti i rami
                k=k+length(i_ramo)+1;
            end
            VEC.coord_rami=coord_rami;
            VEC.codici_rami=codici_rami;
            VEC.aree_monte_rami_km2=[obj.rami(:).area_drenata_km2]';
            VEC.coord_tonode=coord_to_node;
            obj.rami_OP=obj.rami;                         % COPIA dei rami, coordinate operative (estensibili)
            
          
            % Rami a monte e a valle di ogni ramo
            indici_rami_monte=arrayfun(@(i) find(obj.topologia_raster.matrice_confluenze(i,:)), 1:size(obj.topologia_raster.matrice_confluenze,1), 'UniformOutput' ,false);
            indici_ramo_valle=arrayfun(@(i) find(obj.topologia_raster.matrice_confluenze(:,i)), 1:size(obj.topologia_raster.matrice_confluenze,1), 'UniformOutput' ,false);
            [obj.rami.rami_monte]=indici_rami_monte{:};
            [obj.rami.ramo_valle]=indici_ramo_valle{:};
                      
            % Ordine di Strahler
            ordine_Strahler=RiverNetwork.strahler(obj.topologia_raster.matrice_confluenze);
            assert(all(isfinite(ordine_Strahler)),'ERRORE: ordine di Strahler NON assegnato a tutti i rami');
            cell_ordine_Strahler=num2cell(ordine_Strahler);
            [obj.rami.Strahler]=deal(cell_ordine_Strahler{:});
            
            
            % Aste
            obj.n_bacini=length(obj.topologia_raster.rami_bacini);
            obj.aste=struct('codice',[],'rami',[],'coord',[],'area_drenata_km2',[],'bacino',[],'distanze_sorgente',[]);
            [aste_bacini,coord_aste_bacini,aree_aste_bacini]=deal(cell(obj.n_bacini,1));
            codici_bacini_aste=[];
            k=0;
            % Ciclo sui bacini
            for b=1:obj.n_bacini
                % calcolo aste per ogni bacino
                [aste_bacini{b},coord_aste_bacini{b},aree_aste_bacini{b}]=obj.reticolo2aste( obj.topologia_raster.rami_bacini{b}, [obj.rami(:).area_drenata_km2] , {obj.rami(:).coord} , obj.topologia_raster.matrice_confluenze );
                na=length(aste_bacini{b});      % numero di aste per il bacino corrente
                for a=k+1:k+na
                    obj.aste(a).codice=obj.codice_dominio+a;                  % codice asta
                    obj.aste(a).rami=aste_bacini{b}{a-k};                     % rami dell'asta
                    obj.aste(a).coord=coord_aste_bacini{b}{a-k};              % coordinate dei punti dell'asta
                    obj.aste(a).area_drenata_km2=aree_aste_bacini{b}{a-k};    % area drenata dell'asta [km2]
                    obj.aste(a).bacino=b;                                     % indice del bacino di appartenenza dell'asta
                    [obj.rami(obj.aste(a).rami).asta]=deal(a);                % assegnazione dell'asta ai rami che le appartengono
                end
                codici_bacini_aste=[codici_bacini_aste;b*ones(na,1)]; %#ok<AGROW>   % codici totali delle aste
                k=k+na;
            end
            obj.aste_OP=obj.aste;                                             % COPIA operativa delle aste 
            
            
            % Distanze dalla sorgente cumulate lungo le aste
            lunghezze_cumulate_aste=cellfun(@(x) [0; cumsum( diag(RiverNetwork.geoDistanzeKm(x(1:end-1,1), x(1:end-1,2), x(2:end,1), x(2:end,2))) )] ,{obj.aste.coord},'UniformOutput',false);
            [obj.aste(:).distanze_sorgente]=lunghezze_cumulate_aste{:};
            % Distanze dalla sorgente lungo i rami
            tabella_coordinate_lunghezze_aste=[vertcat(obj.aste(:).coord),vertcat(lunghezze_cumulate_aste{:})];
            [~,indici]=ismember(vertcat(obj.rami(:).coord),tabella_coordinate_lunghezze_aste(:,1:2),'rows');
            L_coord_rami=cellfun(@(x) size(x,1),{obj.rami(:).coord});
            distanze_sorgente=mat2cell(tabella_coordinate_lunghezze_aste(indici,3),L_coord_rami,1);
            [obj.rami(:).distanze_sorgente]=distanze_sorgente{:};
            
            
            
            % Bacini
            contorni_bacini=obj.getContorniSetRami(obj.topologia_raster.rami_bacini);     % contorni (guscio convesso, ecc.) di ogni bacino
            obj.bacini=struct('codice',[],'rami',[],'aste',[],'foce',[],'area_km2',[],'coord_contorno',[],'diametro',[],'centroide',[]);
            coord_foci=obj.indici2coord(obj.topologia_raster.indici_foci);                     % coordinate delle foci di tutti i bacini
            for b=1:obj.n_bacini
                obj.bacini(b).codice=obj.codice_dominio+b;                                      % codice del bacino
                obj.bacini(b).rami=obj.topologia_raster.rami_bacini{b};                         % rami del bacino (ordinati per area drenata crescente)
                obj.bacini(b).aste=find(codici_bacini_aste==b);                                 % aste del bacino
                obj.bacini(b).foce=coord_foci(b,:);                                             % coordinate della foce del bacino
                obj.bacini(b).area_km2=max([obj.rami(obj.bacini(b).rami).area_drenata_km2]);    % area del bacino [km2]
                obj.bacini(b).coord_contorno=contorni_bacini(b).coord;                          % coordinate del contorno del bacino
                obj.bacini(b).diametro=contorni_bacini(b).diametro;                             % diametro medio del bacino 
                obj.bacini(b).centroide=contorni_bacini(b).centroide;                           % coordinate del centroide del bacino
            end
            % Copie vettoriali
            VEC.coord_foci=coord_foci;
            VEC.aree_bacini_km2=[obj.bacini(:).area_km2]';
            VEC.diametri_bacini=[obj.bacini(:).diametro]';
            VEC.centroidi_bacini=vertcat(obj.bacini(:).centroide);
            obj.bacini_OP=obj.bacini;                                       % COPIA operativa dei bacini
            
            
            % Strutture vettoriali operative
            obj.VEC=VEC;
            obj.VEC_OP=VEC;
            
            
            % Coordinate rami interpolate su un numero fisso di punti per ogni ramo
            obj.coord_rami_n_punti_interpolazione=NaN(obj.n_punti_interpolazione,obj.n_rami,2);
            for r=1:obj.n_rami
                obj.coord_rami_n_punti_interpolazione(:,r,:)=obj.polilinea2punti(obj.rami(r).coord,obj.n_punti_interpolazione);
            end
            obj.coord_rami_n_punti_interpolazione_OP=obj.coord_rami_n_punti_interpolazione;
            
            % Coordinate aste interpolate su un numero fisso di punti per ogni asta
            obj.coord_aste_n_punti_interpolazione=NaN(obj.n_punti_interpolazione,length(obj.coord_aste_bacini),2);
            for a=1:length(obj.aste)
                obj.coord_aste_n_punti_interpolazione(:,a,:)=obj.polilinea2punti(obj.aste(a).coord,obj.n_punti_interpolazione);
            end
            obj.coord_aste_n_punti_interpolazione_OP=obj.coord_aste_n_punti_interpolazione;
            
            % Punti centrali di ogni ramo
            coord_rami=obj.getCoordSetRami(1:obj.n_rami);
            obj.punti_centrali_rami=RiverNetwork.getPuntiCentriRami(coord_rami);
            obj.punti_centrali_rami_OP=obj.punti_centrali_rami;         % Copia operativa dei punti centrali dei rami
            
            
            % Copia operativa della matrice delle confluenze
            obj.matrice_confluenze_OP=obj.topologia_raster.matrice_confluenze;
            
            % Variabili di servizio (versori radiali)
            n_punti_interpolazione_radiali=obj.n_punti_interpolazione;
            n_angoli=360;
            L=1/(2*n_punti_interpolazione_radiali):1/n_punti_interpolazione_radiali:(1-1/(2*n_punti_interpolazione_radiali));
            obj.x_vettori_radiali=L'*cos(deg2rad(0:(360/n_angoli):360-1));
            obj.y_vettori_radiali=L'*sin(deg2rad(0:(360/n_angoli):360-1));
            
            
            % Inizializzazione parametri tolleranze e corrispondenza reticoli
            obj.Err_Max_Dist_Punti=obj.ERRMAX_DIST_PUNTI;                                         % parametri per la modulazione della tolleranza sulle distanze tra punti
            obj.Err_Max_Area_Bacini=obj.ERRMAX_AREA_BACINI;                                       % parametri per la modulazione della tolleranza sulle differenze tra aree
            obj.Err_Max_Area_Bacini_Non_Assegnati=obj.ERRMAX_AREA_BACINI_NON_ASSEGNATI;           % frazione massima di area di un bacino all'interno del dominio per l'assegnazione
            obj.Pesi_Corrispondenza_Bacini=obj.PESI_CORRISPONDENZA_BACINI;                        % 1. peso distanza, 2. peso aree
            obj.Pesi_Corrispondenza_Bacini_Aggiuntivi=obj.PESI_CORRISPONDENZA_BACINI_AGGIUNTIVI;  % 1. peso distanza, 2. peso aree
            obj.Pesi_Corrispondenza_Aste=obj.PESI_CORRISPONDENZA_ASTE;                            % 1. peso distanza, 2. peso aree
            obj.Pesi_Corrispondenza_Rami=obj.PESI_CORRISPONDENZA_RAMI;                            % 1. peso distanza, 2. peso aree
            obj.Soglia_Area_Rototraslazione=obj.SOGLIA_AREA_ROTOTRASLAZIONE;                      % area massima di un bacino per applicare la rototraslazione [km^2]
            obj.Soglia_Distanza_Aste_Dinamiche=obj.SOGLIA_DISTANZA_ASTE_DINAMICHE;                % soglia per la distanza tra le aste dinamiche e l'asta da assegnare
            obj.N_Max_Aste_Esplorazione=obj.N_MAX_ASTE_ESPLORAZIONE;                              % numero massimo di aste dinamiche da esplorare per la corrispondenza [km]
            obj.Flag_Bacini_Esclusi=obj.FLAG_BACINI_ESCLUSI;                                      % 1 = assegna tutti i bacini idraulici, anche fuori dal boundary del bacino idrologico, 0 = assegna solo i bacini idraulici che ricadono per la maggior parte all'interno del bacino idrologico
            obj.Flag_Foci_Centroidi=obj.FLAG_FOCI_CENTROIDI;                                      % 1 = foci, 2 = centroidi
            obj.Flag_Ricerca_Estesa=obj.FLAG_RICERCA_ESTESA;                                      % 1 = cerca i rami di testata evenatualmente anche fuori dal bacino,  0 = cerca i rami di testata solo tra i rami vicini del bacino
            obj.Flag_Corrispondenza_Aste=obj.FLAG_CORRISPONDENZA_ASTE;                            % 1 = corrispondenza semplice con le aste standard, 2 = aste dinamiche

            
        end
        
                
        function [tabella_corrispondenza_rami,obj]=corrispondenzaReticoli(obj,ReticoliDati,parametri)
            
            % tabella_corrispondenze_rami=corrispondenzaReticoli(ReticoloDati,parametri)
            %
            % Assegna a ogni ramo del reticolo corrente (solitamente idraulico) un ramo corrispondente
            % del/dei reticolo/i in input "ReticoloDati" (solitamente idrologico) e scrive una tabella di corrispondenza 
            % come file .txt, gli shape dei due reticoli (quello idraulico comprende la tabella di corrispondenza) 
            % e uno shape di connettori tra i rami corrispondenti.
            % L'algoritmo di corrispondenza usa un approccio gerarchico: cerca la corrispondenza tra bacini (in assenza di
            % corrispondenti utilizza i sottobacini più simili), poi cerca la corrispondenza tra le aste all'interno di 
            % ogni bacino e poi la corrispondenza tra i rami all'interno di ogni asta.
            % 
            % INPUT
            %   ReticoliDati = reticolo o reticoli con i quali stabilire la corrispondenza (oggetto RiverNetwork o cell array 
            %                  di oggetti RiverNetwork se più di uno, in questo caso i codici dominio devono essere tali da evitare
            %                  rami di reticoli in input diversi aventi lo stesso codice ramo)
            %   parametri (OPZIONALE) = struct che può contenere uno o più dei seguenti campi:
            %                               Err_Max_Dist_Punti : parametri per la modulazione della tolleranza sulle distanze tra punti [errore_minimo errore_massimo esponente]
            %                               Err_Max_Area_Bacini : parametri per la modulazione della tolleranza sulle differenze tra aree [errore_minimo errore_massimo esponente]
            %                               Flag_Foci_Centroidi : usa 1 = foci oppure 2 = centroidi per il calcolo della distanza tra bacini
            %                               Pesi_Corrispondenza_Bacini :  pesi per la funzione di costo [peso_distanza peso_aree]
            %                               Pesi_Corrispondenza_Bacini_Aggiuntivi :  pesi per la funzione di costo [peso_distanza peso_aree]
            %                               Pesi_Corrispondenza_Aste :  pesi per la funzione di costo [peso_distanza peso_aree]
            %                               Pesi_Corrispondenza_Rami :  pesi per la funzione di costo [peso_distanza peso_aree]
            %                               Soglia_Area_Rototraslazione :  area massima di un bacino per applicare la rototraslazione nella corrispondenza di bacini [km^2]
            %                               N_Max_Aste_Esplorazione :  numero massimo di aste dinamiche da esplorare per la corrispondenza
            %                               Flag_Bacini_Esclusi :  1 = assegna tutti i bacini idraulici, anche fuori dal boundary del bacino idrologico, 0 = assegna solo i bacini idraulici che ricadono per la maggior parte all'interno del bacino idrologico
            %                               Flag_Corrispondenza_Aste: 1 = corrispondenza semplice, 2 = aste dinamiche
            %                               Percorso_Output :  percorso in cui salvare i file di risultato (tabella di corrispondenza, shape dei reticoli, shape dei connettori)
            %
            % OUTPUT
            %   tabella_corrispondenze_rami = matrice nrami x 2 contenente per ogni ramo del reticolo (idraulico, prima colonna)
            %                                 il corrispondente ramo del/i reticolo/i ReticoloDati (idrologico, seconda colonna)
            
            
            
            % Parametri dell'algoritmo di corrispondenza
            if nargin==3
                obj=obj.updateParametri(parametri,{'Err_Max_Dist_Punti','Err_Max_Area_Bacini','Flag_Foci_Centroidi',...
                    'Pesi_Corrispondenza_Bacini','Pesi_Corrispondenza_Bacini_Aggiuntivi','Pesi_Corrispondenza_Aste','Pesi_Corrispondenza_Rami',...
                    'Soglia_Area_Rototraslazione','N_Max_Aste_Esplorazione','Flag_Corrispondenza_Aste','Flag_Ricerca_Estesa',...
                    'Flag_Bacini_Esclusi','Percorso_Output'});
                if isfield(parametri,'Percorso_Output')==0
                    parametri.Percorso_Output=[];
                end
            end
            
            % Controllo per la presenza di più reticoli idrologici
            if isa(ReticoliDati,'RiverNetwork')
                ReticoliDati={ReticoliDati};
            end
            
            
            
            % Assegnazione dei bacini idraulici ai reticoli idrologici
            [lista_indici_bacini_idraulici,lista_indici_bacini_idrologici]=obj.assegnazioneBaciniReticoli(ReticoliDati);
            
            
            % Ciclo sui reticoli idrologici
            tabella_corrispondenza_rami=NaN(obj.n_rami,2);
            lunghezze_medie_connettori_rami=NaN(obj.n_rami,1);
            r_rami=0;
            for r=1:length(ReticoliDati)
                
                % Reticolo idrologico corrente
                ReticoloDati=ReticoliDati{r};
                
                
                % Gerarchia 0 - Corrispondenza dei bacini
                [tabella_corrispondenza_bacini,ReticoloDati,tabella_nuovi_indici_rami]=obj.CorrispondenzaBacini(ReticoloDati,lista_indici_bacini_idraulici{r},lista_indici_bacini_idrologici{r});
                
                
                % Gerarchia 1 - Corrispondenza aste
                indici_assegnazioni_bacini=all(isfinite(tabella_corrispondenza_bacini),2);
                [tabella_corrispondenza_aste,ReticoloDati]=obj.searchAsteSimili(ReticoloDati,tabella_corrispondenza_bacini(indici_assegnazioni_bacini,:));
                
                
                % Gerarchia 2 - Corrispondenza rami
                tabella_corrispondenza_rami_reticolo=obj.searchRamiSimili(ReticoloDati,tabella_corrispondenza_aste,tabella_nuovi_indici_rami);
                [~,indici_sort]=sort(tabella_corrispondenza_rami_reticolo(:,1));
                tabella_corrispondenza_rami_reticolo=tabella_corrispondenza_rami_reticolo(indici_sort,:);
                tabella_corrispondenza_rami_reticolo=[[obj.rami(tabella_corrispondenza_rami_reticolo(:,1)).codice]',[ReticoloDati.rami(tabella_corrispondenza_rami_reticolo(:,2)).codice]'];  % rami indicati come codici
                
                
                % Aggiornamento tabella corrispondenza rami totale
                n_rami_bacini_idraulici_correnti=length([ obj.bacini(lista_indici_bacini_idraulici{r}).rami]);
                tabella_corrispondenza_rami(r_rami+1:r_rami+n_rami_bacini_idraulici_correnti,:)=tabella_corrispondenza_rami_reticolo;
                
                
                % Controllo di assegnazione completa
                assert(size(tabella_corrispondenza_rami_reticolo,1)==n_rami_bacini_idraulici_correnti,['WARNING: rami idraulici del dominio ',obj.nome_dominio,' non completamente assegnati dal dominio idrologico ',ReticoliDati{r}.nome_dominio]);
                
                
                
                % Scrittura dei risultati
                
                % scrittura del reticolo idrologico
                ReticoliDati{r}.writeReticoloShape([parametri.Percorso_Output,'Reticolo_idrologico__',ReticoliDati{r}.nome_dominio],[{'Cod_idro'};num2cell(vertcat(ReticoliDati{r}.rami(:).codice))]);
                
                % calcolo dei connettori rami idraulici - rami idrologici
                coord_npunti_rami_idraulico=obj.coord_rami_n_punti_interpolazione(2:3:end,tabella_corrispondenza_rami_reticolo(:,1)-obj.codice_dominio,:);
                coord_npunti_rami_idrologico=ReticoliDati{r}.coord_rami_n_punti_interpolazione(2:3:end,tabella_corrispondenza_rami_reticolo(:,2)-ReticoliDati{r}.codice_dominio,:);
                coord_tratti=RiverNetwork.trattiConnessionePolilinee(coord_npunti_rami_idraulico, coord_npunti_rami_idrologico);
                lunghezze_medie_connettori=NaN(size(coord_tratti,3),1);
                for t=1:size(coord_tratti,3)
                    lunghezze_medie_connettori(t)=mean(diag(RiverNetwork.geoDistanzeKm(coord_tratti(1:3:end,1,t),coord_tratti(1:3:end,2,t),coord_tratti(2:3:end,1,t),coord_tratti(2:3:end,2,t))));
                end
                
                
                % scrittura dello shape dei connettori
                lunghezze_medie_connettori_rami(r_rami+1:r_rami+n_rami_bacini_idraulici_correnti,:)=lunghezze_medie_connettori;
                r_rami=r_rami+n_rami_bacini_idraulici_correnti;
                RiverNetwork.writeShape([parametri.Percorso_Output,'Connettori__',obj.nome_dominio,'__',ReticoliDati{r}.nome_dominio],[num2cell(squeeze(coord_tratti(:,1,:)),1)',num2cell(squeeze(coord_tratti(:,2,:)),1)'],[{'Cod_idra','Cod_idro','Dist_km'};num2cell([tabella_corrispondenza_rami_reticolo,lunghezze_medie_connettori(:)])]);
                
                
            end
            
            
            % scrittura tabella di corrispondenza totale
            [~,indici_sort]=sort(tabella_corrispondenza_rami(:,1));
            tabella_corrispondenza_rami=tabella_corrispondenza_rami(indici_sort,:);
            lunghezze_medie_connettori_rami=lunghezze_medie_connettori_rami(indici_sort);
            RiverNetwork.writeCsv(tabella_corrispondenza_rami,[parametri.Percorso_Output,'Tabella_corrispondenza_rami__',obj.nome_dominio,'.txt']);
            
            % scrittura del reticolo idraulico
            obj.writeReticoloShape([parametri.Percorso_Output,'Reticolo_idraulico__',obj.nome_dominio],[{'Cod_idra','Cod_idro','Dist_km'};num2cell([tabella_corrispondenza_rami,lunghezze_medie_connettori_rami(:)])]);
            
            
        end
        
                
        function tabellaCorrispondenza2Shape(obj,ReticoliDati,tabella_corrispondenza_rami,Percorso_Output)
            
            % tabellaCorrispondenza2Shape(obj,ReticoliDati,tabella_corrispondenza_rami,Percorso_Output)
            %
            % A partire da una tabella di corrispondenza tra reticoli (matrice nrami x 2 contenente per ogni ramo 
            % del reticolo corrente (prima colonna) un corrispondente ramo del reticolo ReticoloDati (seconda colonna) 
            % e da essa genera i risultati della corrispondenza: tabella in formato .txt, shape del reticolo corrente 
            % contenente la tabella stessa, shape del/dei reticoli in input e shape dei connettori.
            % INPUT
            %   ReticoliDati = reticolo o reticoli con i quali stabilire la corrispondenza (oggetto RiverNetwork o cell array 
            %                  di oggetti RiverNetwork se più di uno, in questo caso i codici dominio devono essere tali da evitare
            %                  rami di reticoli in input diversi aventi lo stesso codice ramo, e devono essere coerenti con 
            %                  la seconda colonna della tabella)
            %   tabella_corrispondenza_rami = tabella o file .txt contenente la tabella, matrice nrami x 2 contenente 
            %                                  per ogni ramo del reticolo (idraulico, prima colonna) il corrispondente 
            %                                  ramo del/i reticolo/i ReticoloDati (idrologico, seconda colonna)
            %	Percorso_Output = percorso in cui salvare i file di risultato (tabella di corrispondenza, shape dei reticoli, shape dei connettori)
            

            
            % Controllo input
            if nargin==3 || isempty(Percorso_Output)
                Percorso_Output='./';
            end
            if ischar(tabella_corrispondenza_rami)
                tabella_corrispondenza_rami=load(tabella_corrispondenza_rami);
            end
            
                                    
            
            lunghezze_medie_connettori_rami=NaN(obj.n_rami,1);
            r_rami=0;
            if iscell(ReticoliDati)==0          % caso di un solo reticolo
                
                n_rami_bacini_idraulici_correnti=length(obj.rami);
                
                % scrittura del reticolo idrologico
                ReticoliDati.writeReticoloShape([Percorso_Output,'Reticolo_idrologico__',ReticoliDati.nome_dominio],[{'Cod_idro'};num2cell(vertcat(ReticoliDati.rami(:).codice))]);
                
                % calcolo dei connettori rami idraulici - rami idrologici
                coord_npunti_rami_idraulico=obj.coord_rami_n_punti_interpolazione(2:3:end,tabella_corrispondenza_rami(:,1)-obj.codice_dominio,:);
                coord_npunti_rami_idrologico=ReticoliDati.coord_rami_n_punti_interpolazione(2:3:end,tabella_corrispondenza_rami(:,2)-ReticoliDati.codice_dominio,:);
                coord_tratti=RiverNetwork.trattiConnessionePolilinee(coord_npunti_rami_idraulico, coord_npunti_rami_idrologico);
                lunghezze_medie_connettori=NaN(size(coord_tratti,3),1);
                for t=1:size(coord_tratti,3)
                    lunghezze_medie_connettori(t)=mean(diag(RiverNetwork.geoDistanzeKm(coord_tratti(1:3:end,1,t),coord_tratti(1:3:end,2,t),coord_tratti(2:3:end,1,t),coord_tratti(2:3:end,2,t))));
                end
                                
                % scrittura dello shape dei connettori
                lunghezze_medie_connettori_rami(r_rami+1:r_rami+n_rami_bacini_idraulici_correnti,:)=lunghezze_medie_connettori;
                RiverNetwork.writeShape([Percorso_Output,'Connettori__',obj.nome_dominio,'__',ReticoliDati.nome_dominio],[num2cell(squeeze(coord_tratti(:,1,:)),1)',num2cell(squeeze(coord_tratti(:,2,:)),1)'],[{'Cod_idra','Cod_idro','Dist_km'};num2cell([tabella_corrispondenza_rami,lunghezze_medie_connettori(:)])]);
                
                % Tabella corrispondenza totale
                RiverNetwork.writeCsv(tabella_corrispondenza_rami,[Percorso_Output,'Tabella_corrispondenza_rami__',obj.nome_dominio,'.txt']);
                
                % scrittura del reticolo idraulico
                obj.writeReticoloShape([Percorso_Output,'Reticolo_idraulico__',obj.nome_dominio],[{'Cod_idra','Cod_idro','Dist_km'};num2cell([tabella_corrispondenza_rami,lunghezze_medie_connettori_rami(:)])]);
                
                
            else
                
                
                codici_domini_reticoli_idrologici=NaN(length(ReticoliDati),1);
                for r=1:length(ReticoliDati)
                    codici_domini_reticoli_idrologici(r)=ReticoliDati{r}.codice_dominio;
                end
                codici_domini_reticoli_idrologici=[codici_domini_reticoli_idrologici;max(codici_domini_reticoli_idrologici)*2];
                r_rami=0;
                
                for r=1:length(ReticoliDati)
                    
                    % tabella parziale relativa al reticolo idrologico corrente
                    tabella_corrispondenza_rami_reticolo=tabella_corrispondenza_rami(  tabella_corrispondenza_rami(:,2)>codici_domini_reticoli_idrologici(r) & tabella_corrispondenza_rami(:,2)<min(codici_domini_reticoli_idrologici(codici_domini_reticoli_idrologici>codici_domini_reticoli_idrologici(r))) ,:);
                    n_rami_bacini_idraulici_correnti=size(tabella_corrispondenza_rami_reticolo,1);
                    lunghezze_medie_connettori_rami=NaN(n_rami_bacini_idraulici_correnti,1);
                    
                    % scrittura del reticolo idrologico
                    ReticoliDati{r}.writeReticoloShape([Percorso_Output,'Reticolo_idrologico__',ReticoliDati{r}.nome_dominio],[{'Cod_idro'};num2cell(vertcat(ReticoliDati{r}.rami(:).codice))]);
                    
                    % calcolo dei connettori rami idraulici - rami idrologici
                    coord_npunti_rami_idraulico=obj.coord_rami_n_punti_interpolazione(2:3:end,tabella_corrispondenza_rami_reticolo(:,1)-obj.codice_dominio,:);
                    coord_npunti_rami_idrologico=ReticoliDati{r}.coord_rami_n_punti_interpolazione(2:3:end,tabella_corrispondenza_rami_reticolo(:,2)-ReticoliDati{r}.codice_dominio,:);
                    coord_tratti=RiverNetwork.trattiConnessionePolilinee(coord_npunti_rami_idraulico, coord_npunti_rami_idrologico);
                    lunghezze_medie_connettori=NaN(size(coord_tratti,3),1);
                    for t=1:size(coord_tratti,3)
                        lunghezze_medie_connettori(t)=mean(diag(RiverNetwork.geoDistanzeKm(coord_tratti(1:3:end,1,t),coord_tratti(1:3:end,2,t),coord_tratti(2:3:end,1,t),coord_tratti(2:3:end,2,t))));
                    end
                                        
                    % scrittura dello shape dei connettori
                    lunghezze_medie_connettori_rami(r_rami+1:r_rami+n_rami_bacini_idraulici_correnti,:)=lunghezze_medie_connettori;
                    r_rami=r_rami+n_rami_bacini_idraulici_correnti;
                    RiverNetwork.writeShape(['Connettori__',obj.nome_dominio,'__',ReticoliDati{r}.nome_dominio],[num2cell(squeeze(coord_tratti(:,1,:)),1)',num2cell(squeeze(coord_tratti(:,2,:)),1)'],[{'Cod_idra','Cod_idro','Dist_km'};num2cell([tabella_corrispondenza_rami_reticolo,lunghezze_medie_connettori(:)])]);
                                        
                end
                
                % Tabella corrispondenza totale
                RiverNetwork.writeCsv(tabella_corrispondenza_rami,['Tabella_corrispondenza_rami__',obj.nome_dominio,'.txt']);
                                
                % scrittura del reticolo idraulico
                obj.writeReticoloShape(['Reticolo_idraulico__',obj.nome_dominio],[{'Cod_idra','Cod_idro','Dist_km'};num2cell([tabella_corrispondenza_rami,lunghezze_medie_connettori_rami(:)])]);
                    
                
            end
            
        end
        
        
        function plotReticolo(obj,rami,colore,spessore,flag_label,flag_OP)
            
            % plotReticolo(rami,colore,spessore,flag_label,flag_OP)
            %
            % Plotta il reticolo o un sottoinsieme dei rami.
            % INPUT
            %   rami = vettore con gli indici (NON codici) dei rami (OPZIONALE, se vuoto o mancante = disegna l'intero reticolo)
            %   colore = colore delle linee (OPZIONALE, se vuoto o mancante = 'k')
            %   spessore = spessore delle linee (OPZIONALE, se vuoto o mancante = 1)
            %   flag_label = 0 : nessuna label, 1: label con il codice del ramo (OPZIONALE, se vuoto o mancante = 0)
            %   flag_OP = 0 : plotta il reticolo, 1 : plotta la versione operativa del reticolo (USO INTERNO) (OPZIONALE, se vuoto o mancante = 0)
           
            
            % Controllo input
            if nargin==1
                rami=1:obj.n_rami;
                colore='k';
                spessore=3;
                flag_label=0;
                flag_OP=0;
            elseif nargin==2
                colore='k';
                spessore=3;
                flag_label=0;
                flag_OP=0;
            elseif nargin==3
                spessore=3;
                flag_label=0;
                flag_OP=0;
            elseif nargin==4
                flag_label=0;
                flag_OP=0;
            elseif nargin==5
                flag_OP=0;
            end
            if isempty(rami) && flag_OP==0
                rami=1:obj.n_rami;
            elseif isempty(rami) && flag_OP==1
                rami=1:length(obj.rami_OP);
            end
            if isempty(colore)
                colore='k';
            end
            if isempty(spessore)
                spessore=3;
            end
            
            % selezione coordinate dei rami di interesse
            coord=obj.getCoordSetRami(rami,2,flag_OP+1);
            
            % Figura
            hold on;
            plot(coord(:,1),coord(:,2),'color',colore,'LineWidth',spessore);
            if flag_label==1 && flag_OP==0      % label dei rami
                text(obj.punti_centrali_rami(rami,1),obj.punti_centrali_rami(rami,2),num2str(rami(:)));
            elseif flag_label==1 && flag_OP==1  % label dei rami operativi
                text(obj.punti_centrali_rami_OP(rami,1),obj.punti_centrali_rami_OP(rami,2),num2str(rami(:)));
            end
            
            
        end
        
        
        function plotBacini(obj,bacini,colore,spessore,flag_reticolo,flag_label)
            
            % plotBacini(bacini,colore,spessore,flag_reticolo,flag_label)
            %
            % Plotta i contorni (NON gli spartiacque) dei bacini evidenziando le foci.
            % INPUT
            %   bacini = indici (NON codici) dei bacini (OPZIONALE, se vuoto o mancante = tutti i bacini)
            %   colore = colore delle linee (OPZIONALE, se vuoto o mancanti = 'b')
            %   spessore = spessore delle linee (OPZIONALE, se vuoto o mancante = 1)
            %   flag_reticolo = 1: plotta anche i reticoli, 0: plotta solo i contorni (OPZIONALE, se vuoto o mancante = 0)
            %   flag_label = 1: label con gli indici dei bacini, 0: nessuna label (OPZIONALE, se vuoto o mancante = 0)
            
            % Controllo input
            if nargin==1
                bacini=obj.bacini;
                colore='b';
                spessore=1;
                flag_reticolo=0;
                flag_label=0;
            elseif nargin==2
                colore='b';
                spessore=1;
                flag_reticolo=0;
                flag_label=0;
            elseif nargin==3
                spessore=1;
                flag_reticolo=0;
                flag_label=0;
            elseif nargin==4
                flag_reticolo=0;
                flag_label=0;
            elseif nargin==5
                flag_label=0;
            end
            if isempty(colore)
                colore='b';
            end
            if isempty(spessore)
                spessore=1;
            end
            if isempty(bacini)
                bacini=obj.bacini;
            end
            if isempty(flag_reticolo)
                flag_reticolo=0;
            end
            if isempty(flag_label)
                flag_label=0;
            end
            
            
            
            % plot dei reticoli di ogni bacino e dei rispettivi gusci convessi e foci
            hold on;
            for b=1:length(bacini)
                % plotta il reticolo
                if flag_reticolo
                    obj.plotReticolo(bacini(b).rami,colore,1);
                end
                plot(bacini(b).coord_contorno(:,1),bacini(b).coord_contorno(:,2),'color',colore,'Linewidth',spessore);
                plot(bacini(b).foce(1),bacini(b).foce(2),'^','Color',colore,'MarkerSize',10,'Linewidth',spessore);
                if flag_label==1    % label dei bacini
                    text(bacini(b).foce(1),bacini(b).foce(2),num2str(bacini(b).codice-obj.codice_dominio),'HorizontalAlignment','left','VerticalAlignment','bottom','FontSize',15,'color',colore);
                end
            end
            
        end
        
                
        function writeReticoloShape(obj,nome_file,tabella_campi)
            
            % writeReticoloShape(obj,nome_file,tabella_campi)
            %
            % Scrive il reticolo in uno shape.
            % INPUT
            %   nome_file = nome dello shape file, senza estensione
            %   tabella_campi = cell array di dimensione numero_rami+1 x numero_campi, contenente nella prima riga 
            %                   i nomi dei campi e nelle successive i valori per ogni ramo (OPZIONALE, se vuoto viene creato 
            %                   un campo "Cod_ramo" con i codici dei rami)
            
            
            % Controllo input
            if nargin==2
                tabella_campi=['Cod_ramo';{obj.rami(:).codice}'];
            end
            
            
            % Costruzione delle coordinate dei rami
            coord_rami_x=cellfun(@(c) c(:,1),{obj.rami(:).coord},'UniformOutput',false)';
            coord_rami_y=cellfun(@(c) c(:,2),{obj.rami(:).coord},'UniformOutput',false)';
            
            % scrittura del file shape
            RiverNetwork.writeShape(nome_file,[coord_rami_x,coord_rami_y],tabella_campi);
            
        end
        
        
        function sezioni=putSezioni(obj,coord_sezioni,numero_punti_vicini)
            
            % sezioni=putSezioni(obj,coord_sezioni,numero_punti_vicini)
            %
            % Dispone le sezioni in input sul reticolo, scegliendo il punto di reticolo più vicino e, se disponibile, 
            % con area drenata più simile
            % INPUT
            %   coord_sezioni = matrice n x 2 (x,y di ogni sezione) o n x 3 (x,y,area_drenata di ogni sezione)
            %   numero_punti_vicini = numero di punti di esplorazione tra i vicini per il controllo dell'area (OPZIONALE, se non specificato = 5)
            % OUTPUT
            %   sezioni = struct con i seguenti campi
            %               coord_sezione : nuove coordinate (x,y) della sezione
            %               codice_ramo : codice del ramo a cui la sezione è stata assegnata
            
            
            
            % Controllo input
            if nargin==1
                numero_punti_vicini=5;      % numero di pixel più vicini per il controllo dell'area
            end
            
            
            % Controllo della presenza dell'area drenata delle sezioni
            if size(coord_sezioni,2)==3
                flag_area=1;
                aree_sezioni=coord_sezioni(:,3);
            else
                flag_area=0;
                aree_sezioni=NaN*ones(size(coord_sezioni,1),1);
            end
            
            
            % Coordinate, codici e aree dei punti di ogni ramo del reticolo
            codici_punti_rami=obj.VEC.codici_rami; codici_punti_rami(isnan(obj.VEC.coord_rami(:,1)))=[];
            coord_punti_rami=obj.VEC.coord_rami; coord_punti_rami(isnan(coord_punti_rami(:,1)),:)=[];
            aree_punti_rami=vertcat(obj.rami(:).area_punti_km2);
            
            
            % Contorno del dominio
            indici_contorno=boundary(coord_punti_rami(:,1),coord_punti_rami(:,2));
            coord_contorno=coord_punti_rami(indici_contorno,:);
            
            
            % Eventuali sezioni fuori dal dominio
            indici_sezioni_dentro=find(inpolygon(coord_sezioni(:,1),coord_sezioni(:,2),coord_contorno(:,1),coord_contorno(:,2))>0);
            indici_sezioni_fuori=setdiff(1:size(coord_sezioni,1),indici_sezioni_dentro);
            if isempty(indici_sezioni_fuori)==0
                matrice_distanze=pdist2(coord_contorno,coord_sezioni(indici_sezioni_fuori,:));
                indici_sezioni_dentro=sort([indici_sezioni_dentro(:);indici_sezioni_fuori(min(matrice_distanze)<obj.dx/10)']);
                indici_sezioni_fuori=setdiff(1:size(coord_sezioni,1),indici_sezioni_dentro);
            end
            if size(coord_sezioni,1)==length(indici_sezioni_fuori)
                sezioni=struct('coord_sezione',[],'codice_ramo',[]);
                return
            end
            
            % SPLIT calcolo distanze
            ncols_max_matrice_distanze=ceil(10000^2/size(coord_punti_rami,1));
            if ncols_max_matrice_distanze>length(indici_sezioni_dentro)
                ncols_max_matrice_distanze=length(indici_sezioni_dentro);
            end
            i1=1:ncols_max_matrice_distanze:length(indici_sezioni_dentro);
            i2=unique([ncols_max_matrice_distanze:ncols_max_matrice_distanze:length(indici_sezioni_dentro),length(indici_sezioni_dentro)]);
            matrice_indici_sort=single(NaN(numero_punti_vicini,length(indici_sezioni_dentro)));
            for i=1:length(i1)
                matrice_distanze_parz=pdist2(coord_punti_rami,coord_sezioni(indici_sezioni_dentro(i1(i):i2(i)),:));
                [~,indici_sort]=sort(matrice_distanze_parz);
                matrice_indici_sort(:,i1(i):i2(i))=indici_sort(1:numero_punti_vicini,:);
            end
            % Considera le aree derenate delle sezioni, se presenti
            if flag_area==1
                [~,indici_minimi]=min(abs( aree_punti_rami(matrice_indici_sort) - ones(numero_punti_vicini,1)*aree_sezioni(:)'));
                indici_punti_assegnati=matrice_indici_sort(sub2ind(size(matrice_indici_sort),indici_minimi,1:size(matrice_indici_sort,2)));
            else
                indici_punti_assegnati=matrice_indici_sort(1,:);
            end
            % assegnazione delle sezioni ai rami del reticolo
            coord_punti_assegnati=coord_punti_rami(indici_punti_assegnati,:);
            codici_rami_assegnati=obj.codice_dominio+codici_punti_rami(indici_punti_assegnati);
            
            % Sezioni finali
            sezioni=repmat(struct('coord_sezione',[],'codice_ramo',[]),size(coord_sezioni,1),1);
            sezioni(indici_sezioni_dentro)=struct('coord_sezione',num2cell(coord_punti_assegnati,2),'codice_ramo',num2cell(codici_rami_assegnati));
            
            
        end
        
        
        function sezioni=getSezioni(obj,nome_file_output)
            
            % sezioni=getSezioni(obj,nome_file_output)
            %
            % Estrae una sezione per ramo (il penultimo punto più a valle, per evitare le confluenze), 
            % assegnando il codice del ramo stesso. 
            % INPUT
            %   nome_file_output (OPZIONALE) = nome del file in cui scrivere le sezioni (.csv/.txt oppure .shp)
            % OUTPUT
            %   sezioni = struct con i seguenti campi
            %               coord_sezione : nuove coordinate (x,y) della sezione
            %               codice_ramo : codice del ramo a cui la sezione è stata assegnata
            
            
            % Inizializzazione
            coord_sezioni=NaN(obj.n_rami,2);
            coord_rami={obj.rami(:).coord};
            codici_sezioni=[obj.rami(:).codice];
            
            % numero di punti di ogni ramo
            n_punti_rami=cellfun(@(x) x(1), cellfun(@size, coord_rami,'UniformOutput',false));
            
            % rami di lunghezza 1 e di lunghezza maggiore
            indici_rami_lunghezza_1=find(n_punti_rami==1);
            indici_rami_rimanenti=setdiff(1:obj.n_rami,indici_rami_lunghezza_1);
            
            % estrae l'unico punto nei rami di lunghezza 1 e il penultimo punto più a valle negli altri rami
            coord_sezioni(indici_rami_lunghezza_1,:)=vertcat(obj.rami(indici_rami_lunghezza_1).coord);
            coord_sezioni(indici_rami_rimanenti,:)=cell2mat(cellfun(@(x) x(end-1,:), coord_rami(indici_rami_rimanenti),'UniformOutput',false)');
            
            % Costruzione della struct di risultato
            sezioni=struct('coord_sezione',num2cell(coord_sezioni,2),'codice_ramo',num2cell(codici_sezioni(:)));
            
            % scrittura su file
            if nargin==2 && ischar(nome_file_output)
                [~,~,estensione]=fileparts(nome_file_output);
                switch estensione
                    case {'.txt','.csv'}
                        RiverNetwork.writeCsv([coord_sezioni,codici_sezioni(:)], nome_file_output, ' ');
                    case {'.shp'}
                        shapewrite(struct('Geometry','Point','X',coord_sezioni(:,1),'Y',coord_sezioni(:,2),'codice_sezione',codici_sezioni(:),nome_file_output));
                end
            end

            
        end
                
        
        function mappa=rami2Mappa(obj,valori_rami,nome_file)
            
            % [mappa,x_mappa,y_mappa]=rami2Mappa(obj,valori_rami)
            %
            % Crea una mappa sulla stessa griglia delle idroderivate originali del reticolo in cui rasterizza 
            % i rami assegnano a ognuno i valori input.
            % INPUT
            %   valori_rami = vettore con i valori assegnati a ciascun ramo
            %   nome_file = nome del file raster in cui scrivere la mappa
            % OUTPUT
            %   mappa = struct con i seguenti campi
            %               mappa : mappa con i valori assegnati ai rami
            %               x : vettore delle ascisse
            %               y : vettore delle ordinate
            
            
            
            % Coordinate matrice dei punti dei rami
            ij_rami=obj.coord2Indici(obj.VEC.coord_rami);
            indici_rami=sub2ind([obj.nrows obj.ncols],ij_rami(:,1),ij_rami(:,2));
            
            % Creazione della mappa e assegnaizone dei valori in ognu punto di ogni ramo
            mappa=NaN(obj.nrows,obj.ncols);
            mappa(indici_rami(isfinite(indici_rami)))=valori_rami(obj.VEC.codici_rami(isfinite(indici_rami)));
            mappa=struct('mappa',mappa,'x',obj.x,'y',obj.y);
            
            % scrittura della mappa su file
            if nargin==3
                RiverNetwork.mat2geotiff(nome_file,mappa.mappa,mappa.x,mappa.y);
            end
            
            
        end
        
        
        function valori_rami=mappa2Rami(obj,mappa,flag_punti)
            
            % valori_rami=mappa2Rami(obj,mappa,flag_punti)
            %
            % Assegna a ogni ramo del reticolo i valori corrispondenti di una mappa.
            % INPUT
            %   mappa = nome di un file raster, oppure struct con i seguenti campi
            %               mappa : mappa con i valori assegnati ai rami, sulla stessa griglia delle
            %                       idroderivate originali
            %               x : vettore delle ascisse
            %               y : vettore delle ordinate
            %   flag_punti = 0 : assegna un valore unico a ogni ramo (quello più frequente), 1 : assegna un valore a ogni punto di ogni ramo
            % OUTPUT
            %   valori_rami = vettore o cell array con un elemento per ramo
            
            
            % Controllo input
            if nargin==2
                flag_punti=1;
            end
            
            % lettura mappa
            if ischar(mappa)
                [mappa,x,y,flag_errore_lettura]=RiverNetwork.letturaRaster(mappa,''); %#ok<PROPLC>
                mappa=struct('mappa',mappa,'x',x,'y',y); %#ok<PROPLC>
                if flag_errore_lettura
                    return
                end
            end
            
            % coordinate mappa
            dx_mappa=abs(mappa.x(2)-mappa.x(1));
            dy_mappa=abs(mappa.y(2)-mappa.y(1));
            [nrows,ncols]=size(mappa.mappa); %#ok<PROPLC>
            
            % coordinate dei punti dei rami in coordinate matrice della mappa
            coord_rami=obj.VEC.coord_rami;
            ij_rami=[ nrows-ceil((coord_rami(:,2)-(min(mappa.y)-dy_mappa/2))/dy_mappa)+1 ,   ceil((coord_rami(:,1)-(min(mappa.x)-dx_mappa/2))/dx_mappa)]; %#ok<PROPLC>
            
            % indici dei punti contenuti all'interno della mapppa
            indici_OK=find(ij_rami(:,1)>0 & ij_rami(:,1)<=nrows & isfinite(ij_rami(:,1)) &  ij_rami(:,2)>0 & ij_rami(:,2)<=ncols & isfinite(ij_rami(:,2))); %#ok<PROPLC>
            
            
            % assegnazione dei valori della mappa ai punti dei rami
            valori_rami_vec=NaN(size(coord_rami,1),1);
            valori_rami_vec(indici_OK)=mappa.mappa(sub2ind(size(mappa.mappa),ij_rami(indici_OK,1),ij_rami(indici_OK,2)));
            indici_separazione=find(isnan(coord_rami(:,1)));
            indici_inizio=[1;indici_separazione(1:end-1)+1];
            indici_fine=indici_separazione-1;
            valori_rami=arrayfun(@(i1,i2) valori_rami_vec(i1:i2), indici_inizio, indici_fine,'UniformOutput',false);
            
            % Assegnazione di un valore unico per ramo
            if flag_punti==0   
                valori_rami=cellfun(@(x) mode(x),cellfun(@sort,valori_rami,'UniformOutput',false));
            end
            
        end
        
        
        function isEqual = isEqualTo(obj, Reticolo2)
            
            % isEqual = isEqualTo(Reticolo2)
            %
            % Confronta se due istanze sono uguali.
            % INPUT
            %   Reticolo2 = oggetto con il quale confrontare il reticolo corrente
            %
            % OUTPUT
            %   isEqual = 0: gli oggetti differiscono per almeno una property, 1: Reticolo2 è identico al reticolo corrente
            
            
            % Verifica che i due oggetti siano della stessa classe
            if ~strcmp(class(obj), class(Reticolo2))
                error('Le due istanze non sono della stessa classe.');
            end
            
            % Estrae tutte le proprietà della classe (pubbliche, protette e private)
            mc = metaclass(obj);
            proprieta = mc.Properties;
                        
            % Confronta tutte le proprietà
            isEqual = true;
            for p = 1:length(proprieta)
                
                nome_proprieta = proprieta{p}.Name;
                valore_proprieta_obj = obj.(nome_proprieta);
                valore_proprieta_reticolo2 = Reticolo2.(nome_proprieta);
                
                % Confronta i valori
                if ~RiverNetwork.confrontaValori(valore_proprieta_obj, valore_proprieta_reticolo2)
                    fprintf('Le proprietà "%s" sono diverse.\n', nome_proprieta);
                    isEqual = false;
                    keyboard
                    break;
                end
            end
            
        end
        
                
    end
    
    
    
    methods (Access = private)
                
        
        function angolo_rami=DirezionePolilinee(obj,rami)
            
            % angolo_rami=DirezionePolilinee(obj,rami)
            %
            % Calcola l'inclinazione media di un gruppo di rami (es.: tutti i rami di un bacino)
            % INPUT
            %   rami = indici (NON codici) dei rami di cui calcolare l'inclinazione media
            % OUTPUT
            %   angolo_rami = angolo dell'inclinazione media [°]
            
            
            coord=obj.getCoordSetRami(rami,2);
            coord(isnan(coord(:,1)),:)=[];
            AV=eig(cov(coord-mean(coord)));   % autovettori della matrice di covarianza
            angolo_rami=rad2deg(atan2(AV(2,end),AV(1,end)));
            
        end
        
        
        function obj=updateParametri(obj,parametri,nomi_parametri) %#ok<INUSL>
            
            % obj=updateParametri(obj,parametri,nomi_parametri)
            % 
            % Modifica i parametri dell'algoritmo di corrispondenza
            % INPUT
            %   parametri = struct che può contenere nome/valore di vari parametri
            %   nomi_parametri = elenco totale dei parametri da controllare
            
            for p=1:length(nomi_parametri)
                eval(['if isfield(parametri,nomi_parametri{p}) && isempty(parametri.',nomi_parametri{p},')==0, obj.',nomi_parametri{p},'=parametri.',nomi_parametri{p},'; end']);
            end
            
        end
        
        
        function coord_contorno=coordContornoBacini(obj,indici_bacini)
            
            % coord_contorno=coordContornoBacini(obj,indici_bacini)
            %
            % Genera il contorno di uno o più bacini (NON lo spartiacque, ma il poligono che passa per i punti più "esterni" 
            % del reticolo del bacino stesso e segue approssimativamente la sua forma)
            % INPUT
            %   indici_bacini = indici (NON codici) dei bacini di cui
            %   calcolare il contorno (OPZIONALE: se non specificato = tutti i bacini)
            % OUPUT
            %   coord_contorno = matrice n x 2 con le coordinate del contorno
            
            % Controllo input
            if nargin==1 || isempty(indici_bacini)
                indici_bacini=1:obj.n_bacini;
            end
            
            % calcolo contorni dei bacini
            coord_punti=obj.VEC.coord_rami(ismember(obj.VEC.codici_rami,[obj.bacini(indici_bacini).rami]),:);
            coord_punti(isnan(coord_punti(:,1)),:)=[];
            indici_punti_contorno=boundary(coord_punti(:,1),coord_punti(:,2));
            coord_contorno=[coord_punti(indici_punti_contorno,1),coord_punti(indici_punti_contorno,2)];
            
        end
        
        
        function coord=indici2coord(obj,I)
            
            % coord=indici2coord(obj,I)
            %
            % Conversione da coordinate matrice (sulla griglia delle idroderivate originali) a coordinate (x,y)
            % INPUT
            %   I = coordinate relative (i,j) o assolute (i) matrice
            % OUTPUT
            %   coord = coordinate (x,y) dei punti
            
            
            if size(I,2)==1
                [i,j]=ind2sub([obj.nrows,obj.ncols],I);
                coord=[obj.x(j)',obj.y(obj.nrows-i+1)'];
            else
                coord=[obj.x(I(:,2))',obj.y(obj.nrows-I(:,1)+1)'];
            end
            
        end
        
        
        function indici_punti=coord2Indici(obj,coord_punti)
            
            % indici_punti=coord2Indici(obj,coord_punti)
            %
            % Calcola le coordinate matrice (nella griglia delle
            % idroderivate originali) a partire da coordinate geografiche dei punti
            % INPUT
            %   coord_punti = matrice n x 2 con le coordinate (x,y) dei punti
            % OUPUT
            %   indici_punti = matrice n x 2 con le coordinate matrice (i,j) dei punti
            
            indici_punti=[obj.nrows-ceil((coord_punti(:,2)-(min(obj.y)-obj.dy/2))/obj.dy)+1,ceil((coord_punti(:,1)-(min(obj.x)-obj.dx/2))/obj.dx)];
            
        end
        
        
        function coord_rami_rototraslati=rototraslazione(obj,rami,vettore_distanza,angolo,polo)
            
            % coord_rami_rototraslati=rototraslazione(obj,rami,vettore_distanza,angolo,polo)
            % 
            % Rototraslazione rigida di un insieme di rami
            % INPUT
            %   rami = indici (NON codici) dei rami da rototraslare
            %   vettore_distanza = vettore (dx,dy) per la traslazione
            %   angolo = angolo di rotazione nel piano [rad]
            %   polo = vettore (x,y) con le coordinate del polo di rotazione
            % OUTPUT
            %   coord_rami_rototraslati = matrice n x 2 con le coordinate di tutti i punti dei rami rototraslati
            
            coord_rami_rototraslati=rototraslazionePolilinee(obj.getCoordSetRami(rami,2),vettore_distanza,angolo,polo);
            
        end
        
        
        function [lista_indici_bacini_idraulici,lista_indici_bacini_idrologici]=assegnazioneBaciniReticoli(obj,ReticoliDati)
            
            % [lista_indici_bacini_idraulici,lista_indici_bacini_idrologici]=assegnazioneBaciniReticoli(obj,ReticoliDati)
            %
            % Assegnazione dei gruppi di bacini idraulici ai gruppi di bacini idrologici (in caso di reticoli idrologici multipli 
            % suddivide gli appropriati bacini idraulici).
            % INPUT
            %   ReticoliDati = reticolo/i con i/il quale/i costruire l'assegnazione
            % OUPUT
            %   lista_indici_bacini_idraulici = raggruppamento degli indici (NON codici) dei bacini idraulici
            %   lista_indici_bacini_idrologici = raggruppamento degli indici (NON codici) dei bacini idrologici
            
            
            % Ricerca quali bacini sono compresi nell'area più piccola tra quella del reticolo idraulico e quella del reticolo idrologico
            [lista_indici_bacini_idraulici,lista_indici_bacini_idrologici]=deal(cell(length(ReticoliDati),1));
            for r=1:length(ReticoliDati)
                [lista_indici_bacini_idraulici{r},lista_indici_bacini_idrologici{r}]=ricercaBaciniAreaComune(obj,ReticoliDati{r});
            end
            
            % Eventualmente assegna tutti i bacini idraulici, anche fuori dal boundary del bacino idrologico
            if obj.Flag_Bacini_Esclusi==1
                indici_bacini_esclusi=setdiff(1:obj.n_bacini,vertcat(lista_indici_bacini_idraulici{:}));  % bacini idraulici non inclusi in nessuna area
                if isempty(indici_bacini_esclusi)==0
                    
                    % coordinate dei centroidi dei bacini esclusi
                    centroidi_bacini_esclusi=vertcat(obj.bacini(indici_bacini_esclusi).centroide);
                    
                    % contorni per tutti i reticoli idrologici
                    coord_contorni_reticoli_dati=cell(length(ReticoliDati),1);
                    for b=1:length(ReticoliDati)
                        coord_contorni_reticoli_dati{b}=ReticoliDati{b}.coordContornoBacini([]);
                    end
                    
                    % assegnazione dei bacini idraulici esclusi ai reticoli idrologici
                    distanze_centroidi_reticoli=NaN(length(indici_bacini_esclusi),length(ReticoliDati));
                    for r=1:length(ReticoliDati)
                        distanze_centroidi_reticoli(:,r)=min(pdist2(centroidi_bacini_esclusi,coord_contorni_reticoli_dati{r}),[],2);
                    end
                    [~,indici_minimi]=min(distanze_centroidi_reticoli,[],2);
                    
                    
                    % calcolo indici bacii idraulici assegnati ai reticoli idrologici
                    for r=1:length(ReticoliDati)
                        indici_bacini_da_includere=find(indici_minimi==r);
                        if isempty(indici_bacini_da_includere)==0
                            lista_indici_bacini_idraulici{r}=sort([lista_indici_bacini_idraulici{r}(:);indici_bacini_esclusi(indici_bacini_da_includere(:))']);
                        end
                    end
                    
                    
                end
            end
            
            
        end
        
        
        function [indici_bacini_idraulici,indici_bacini_idrologici]=ricercaBaciniAreaComune(obj,ReticoloDati)
            
            % [indici_bacini_idraulici,indici_bacini_idrologici]=ricercaBaciniAreaComune(obj,ReticoloDati)
            %
            % Ricerca quali bacini sono compresi nell'area più piccola tra quella del reticolo idraulico e quella del reticolo idrologico
            % INPUT
            %   ReticoloDati = reticolo con il quale costruire l'assegnazione
            % OUTPUT
            %   indici_bacini_idraulici = indici dei bacini idraulici per la maggior parte all'interno dell'area comune tra i reticoli
            %   indici_bacini_idrologici = indici dei bacini idrologici per la maggior parte all'interno dell'area comune tra i reticoli
            
            
            % Area entro la quale vanno cercate le corrispondenze (la più piccola tra il contorno idraulico e quello idrologico)
            area_reticolo_idraulico=sum(obj.VEC.aree_bacini_km2);
            area_reticolo_idrologico=sum([ReticoloDati.VEC.aree_bacini_km2]);
            if area_reticolo_idraulico>area_reticolo_idrologico
                coord_punti=ReticoloDati.VEC.coord_rami;
            else
                coord_punti=obj.VEC.coord_rami;
            end
            coord_punti(isnan(coord_punti(:,1)),:)=[];
            coord_contorno=coord_punti(boundary(coord_punti),:);
            
            % Selezione dei bacini in base alla percentuale di area compresa nell'area di interesse
            perc_bacini_dentro_idraulici=obj.PercIntersezioneBacini(coord_contorno);
            perc_bacini_dentro_idrologici=ReticoloDati.PercIntersezioneBacini(coord_contorno);
            indici_bacini_idraulici=find(perc_bacini_dentro_idraulici>0.5);
            indici_bacini_idrologici=find(perc_bacini_dentro_idrologici>0.5);
            
        end
        
        
        function [tabella_corrispondenza_bacini,ReticoloDati,tabella_nuovi_indici_rami]=CorrispondenzaBacini(obj,ReticoloDati,indici_bacini_idraulici,indici_bacini_idrologici)
            
            % [tabella_corrispondenza_bacini,ReticoloDati,tabella_nuovi_indici_rami]=CorrispondenzaBacini(obj,ReticoloDati,indici_bacini_idraulici,indici_bacini_idrologici)
            %
            % Calcolo la corrispondenza tra i bacini.
            % INPUT
            %   ReticoloDati = reticolo con il quale costruire l'assegnazione
            %   indici_bacini_idraulici = indici (NON codici) dei bacini idraulici selezionati per la corrispondenza
            %   indici_bacini_idrologici = indici (NON codici) dei bacini idrologici selezionati per la corrispondenza
            % OUTPUT
            %   tabella_corrispondenza_bacini = matrice n x 3, colonna 1: bacini idraulici, 2: bacini idrologici corrispondenti, 3: tipo di assegnazione (1 = standard, 2 = sottobacini)
            %   ReticoloDati = reticolo aggiornato (eventualmente con sottobacini virtuali operativi)
            %	tabella_nuovi_indici_rami = matrice n x 2 con gli indicidei "nuovi" rami virtuali del reticolo ReticoloDati (colonna 1) 
            %                               e i	corrispodennti indici originali (colonna 2)
            
            
            
            % CORRISPONDENZA BACINI per foce/centroide/Aree
            
            % Inizializzazione tabella di corrispondenza dei bacini (colonna 1: bacini idraulici, 2: bacini idrologici corrispondenti, 3: tipo di assegnazione, 1 = standard, 2 = sottobacini)
            tabella_corrispondenza_bacini=NaN(obj.n_bacini,3);
            tabella_corrispondenza_bacini(:,1)=1:obj.n_bacini;
            
            % Corrispondenze dei bacini idrologici -> idraulici
            if obj.Flag_Foci_Centroidi==1
                tabella_corrispondenza_bacini_parz=obj.searchBaciniSimili( ReticoloDati.VEC.coord_foci(indici_bacini_idrologici,:) , obj.VEC.coord_foci(indici_bacini_idraulici,:) , obj.VEC.diametri_bacini(indici_bacini_idraulici) , ReticoloDati.VEC.aree_bacini_km2(indici_bacini_idrologici) , obj.VEC.aree_bacini_km2(indici_bacini_idraulici), obj.Pesi_Corrispondenza_Bacini, 1);
            elseif obj.Flag_Foci_Centroidi==2
                tabella_corrispondenza_bacini_parz=obj.searchBaciniSimili( vertcat(ReticoloDati.bacini(indici_bacini_idrologici).centroide) , vertcat(obj.bacini(indici_bacini_idraulici).centroide) , obj.VEC.diametri_bacini(indici_bacini_idraulici) , ReticoloDati.VEC.aree_bacini_km2(indici_bacini_idrologici) , obj.VEC.aree_bacini_km2(indici_bacini_idraulici), obj.Pesi_Corrispondenza_Bacini, 1);
            end
            tabella_corrispondenza_bacini_parz(:,1)=indici_bacini_idraulici;
            indici_assegnati=find(isfinite(tabella_corrispondenza_bacini_parz(:,2)));
            tabella_corrispondenza_bacini(indici_bacini_idraulici(indici_assegnati),2)=indici_bacini_idrologici(tabella_corrispondenza_bacini_parz(indici_assegnati,2));
            tabella_corrispondenza_bacini(indici_bacini_idraulici(indici_assegnati),3)=1;
            
            
            % CORRISPONDENZA eventuali bacini non assegnati
            indici_bacini_idraulici_non_assegnati=indici_bacini_idraulici(isnan(tabella_corrispondenza_bacini(indici_bacini_idraulici,2)));
            if isempty(indici_bacini_idraulici_non_assegnati)==0
                
                rami_ammissibili_reticolo_idrologico=ReticoloDati.topologia_raster.rami_bacini(indici_bacini_idrologici)';
                rami_ammissibili_reticolo_idrologico=[rami_ammissibili_reticolo_idrologico{:}];
                
                % Corrispondenze di sottobacini idrologici -> idraulici
                tabella_corrispondenza_bacini_parz2=obj.searchBaciniSimili( ReticoloDati.VEC.coord_tonode(rami_ammissibili_reticolo_idrologico,:) , obj.VEC.coord_foci(indici_bacini_idraulici_non_assegnati,:) , obj.VEC.diametri_bacini(indici_bacini_idraulici_non_assegnati) , ReticoloDati.VEC.aree_monte_rami_km2(rami_ammissibili_reticolo_idrologico) , obj.VEC.aree_bacini_km2(indici_bacini_idraulici_non_assegnati), obj.Pesi_Corrispondenza_Bacini_Aggiuntivi, 0);
                tabella_corrispondenza_bacini_parz2(:,2)=rami_ammissibili_reticolo_idrologico(tabella_corrispondenza_bacini_parz2(:,2));
                
                % Creazione bacini aggiuntivi (= sottobacini di bacini idrologici)
                [ReticoloDati,tabella_nuovi_indici_rami]=ReticoloDati.addBaciniAggiuntivi(ReticoloDati.RamiBaciniMonte(tabella_corrispondenza_bacini_parz2(:,2),ReticoloDati.topologia_raster.matrice_confluenze));
                tabella_corrispondenza_bacini_parz2(:,1)=indici_bacini_idraulici_non_assegnati;
                tabella_corrispondenza_bacini_parz2(:,2)=ReticoloDati.n_bacini+1:ReticoloDati.n_bacini+size(tabella_corrispondenza_bacini_parz2,1);
                
                
                % Aggiornamento della tabella di corrispondenza
                tabella_corrispondenza_bacini(indici_bacini_idraulici_non_assegnati,2)=tabella_corrispondenza_bacini_parz2(:,2);
                tabella_corrispondenza_bacini(indici_bacini_idraulici_non_assegnati,3)=2;
                
            else
                
                tabella_nuovi_indici_rami=zeros(0,2);
                
            end
            
            
            % GRAFICO CONTORNI BACINI
            flag_figura=0;
            if flag_figura==1
                
                indici_ok=find(isfinite(tabella_corrispondenza_bacini(:,2)));
                indici_bacini_assegnati=find(tabella_corrispondenza_bacini(:,3)==1);
                indici_sottobacini_assegnati=find(tabella_corrispondenza_bacini(:,3)==2);
                
                % Figura
                figure; hold on;
                RiverNetwork.figureScreenRatio([obj.getCoordSetRami([obj.bacini(indici_bacini_idraulici).rami],2);ReticoloDati.getCoordSetRami([ReticoloDati.bacini(indici_bacini_idrologici).rami],2)]);
                % Plot dei contorni bacini idraulici e idrologici nell'area di interesse
                obj.plotBacini(obj.bacini(indici_bacini_idraulici),[0 0 0.6],1,0,1);
                ReticoloDati.plotBacini(ReticoloDati.bacini(indici_bacini_idrologici),[0.6 0 0],1,0,1);
                % Plot dei contorni dei bacini idraulici assegnati a bacini e dei bacini idrologici corrispondenti
                obj.plotBacini(obj.bacini(indici_ok),[0 0 1],2,0);
                ReticoloDati.plotBacini(ReticoloDati.bacini(tabella_corrispondenza_bacini(indici_bacini_assegnati,2)),[1 0 0],2,0); %#ok<FNDSB>
                % Vettori di connessione tra le foci
                vettori_connessione=[reshape(obj.VEC.coord_foci(tabella_corrispondenza_bacini(indici_ok,1),:)' ,length(indici_ok)*2,1)';...
                    reshape(ReticoloDati.VEC_OP.coord_foci(tabella_corrispondenza_bacini(indici_ok,2),:)',length(indici_ok)*2,1)';...
                    NaN(1,length(indici_ok)*2)];
                vettori_connessione=[reshape(vettori_connessione(:,1:2:end),numel(vettori_connessione)/2,1),reshape(vettori_connessione(:,2:2:end),numel(vettori_connessione)/2,1)];
                plot(vettori_connessione(:,1),vettori_connessione(:,2),'c','Linewidth',2);
                %plot(coord_contorno(:,1),coord_contorno(:,2),'k','Linewidth',3);
                plot(obj.VEC.coord_foci(indici_bacini_idraulici,1),obj.VEC.coord_foci(indici_bacini_idraulici,2),'bo','MarkerSize',10);
                plot(ReticoloDati.VEC_OP.coord_foci(indici_bacini_idrologici,1),ReticoloDati.VEC_OP.coord_foci(indici_bacini_idrologici,2),'ro','MarkerSize',10);
                
                % PLOT BACINI AGGIUNTIVI
                if isempty(indici_bacini_idraulici_non_assegnati)==0
                    plot(obj.VEC.coord_foci(indici_bacini_idraulici_non_assegnati,1),obj.VEC.coord_foci(indici_bacini_idraulici_non_assegnati,2),'g*','MarkerSize',15,'LineWidth',2)
                    vettori_connessione_aggiuntivi=[reshape(obj.VEC.coord_foci(tabella_corrispondenza_bacini_parz2(:,1),:)' ,size(tabella_corrispondenza_bacini_parz2,1)*2,1)';...
                        reshape(ReticoloDati.VEC_OP.coord_foci(tabella_corrispondenza_bacini_parz2(:,2),:)',size(tabella_corrispondenza_bacini_parz2,1)*2,1)';...
                        NaN(1,size(tabella_corrispondenza_bacini_parz2,1)*2)];
                    vettori_connessione_aggiuntivi=[reshape(vettori_connessione_aggiuntivi(:,1:2:end),numel(vettori_connessione_aggiuntivi)/2,1),reshape(vettori_connessione_aggiuntivi(:,2:2:end),numel(vettori_connessione_aggiuntivi)/2,1)];
                    plot(vettori_connessione_aggiuntivi(:,1),vettori_connessione_aggiuntivi(:,2),'g','Linewidth',2);
                    obj.plotBacini(ReticoloDati.bacini_OP(tabella_corrispondenza_bacini(indici_sottobacini_assegnati,2)),[0 1 0],2,0); %#ok<FNDSB>
                end
                
            end
            
            
        end
        
        
        function tabella_corrispondenza_bacini=searchBaciniSimili(obj, coord_foci_idrologico, coord_foci_idraulico, diametri_bacini_idraulico, aree_bacini_idrologico, aree_bacini_idraulico, pesi, flag_tolleranza)
            
            % tabella_corrispondenza_bacini=searchBaciniSimili(obj, coord_foci_idrologico, coord_foci_idraulico, diametri_bacini_idraulico, aree_bacini_idrologico, aree_bacini_idraulico, pesi, flag_tolleranza)
            %
            % Cerca i bacini più simili a quelli di partenza in base a vicinanza delle foci e somiglianza delle aree
            % INPUT
            %   coord_foci_idrologico = matrice n x 2 con le coordinate delle foci dei bacini idrologici
            %   coord_foci_idraulico = matrice n x 2 con le coordinate delle foci dei bacini idraulici
            %   diametri_bacini_idraulico = diametri dei bacini idraulici
            %   aree_bacini_idrologico = aree dei bacini idrologici
            %   aree_bacini_idraulico = aree dei bacini idraulici
            %   pesi = pesi per la funzione di costo [peso_distanza peso_aree]
            %   flag_tolleranza = 0 : ammette tutte le coppie di bacini, 1: applica una tolleranza massima per le componenti della funzione di costo
            % OUTPUT
            %   tabella_corrispondenza_bacini = matrice n x 2 con i bacini idrologici corrispondenti nella colonna 2
            
            
            n_bacini_idrologici=size(coord_foci_idrologico,1);
            
            % Distanze tra foci/centroidi e differenze tra le aree dei bacini
            distanze_foci=RiverNetwork.geoDistanzeKm(coord_foci_idrologico(:,1),coord_foci_idrologico(:,2),coord_foci_idraulico(:,1),coord_foci_idraulico(:,2));
            differenze_aree_bacini=obj.DifferenzeVettori(aree_bacini_idrologico,aree_bacini_idraulico);
            
            % Distanze/differenze adimensionali
            distanze_foci_ADIM=distanze_foci./(ones(n_bacini_idrologici,1)*(diametri_bacini_idraulico'));
            differenze_aree_bacini_ADIM=abs(differenze_aree_bacini)./(ones(n_bacini_idrologici,1)*(aree_bacini_idraulico'));
            
            % Fasce ammissibili di errore
            ErroriMax_DistFoci=obj.ToleranceError(obj.AreeBacini_MinMax_err, obj.Err_Max_Dist_Punti, aree_bacini_idraulico);
            ErroriMax_areaBacini=obj.ToleranceError(obj.AreeBacini_MinMax_err, obj.Err_Max_Area_Bacini, aree_bacini_idraulico);
            
            % Funzione di costo
            J=pesi(1)*(distanze_foci_ADIM./(ones(n_bacini_idrologici,1)*std(distanze_foci_ADIM))).^2+...
                pesi(2)*(differenze_aree_bacini_ADIM./(ones(n_bacini_idrologici,1)*std(differenze_aree_bacini_ADIM))).^2;
            if flag_tolleranza==1
                indici_ammissibili=find(distanze_foci_ADIM<(ones(n_bacini_idrologici,1)*ErroriMax_DistFoci') &...
                    differenze_aree_bacini_ADIM<(ones(n_bacini_idrologici,1)*ErroriMax_areaBacini'));
                J(setdiff(1:numel(J),indici_ammissibili))=Inf;
            end
            [minimi,indici_ottimo]=min(J,[],1);   % bacini che minimizzano il funzionale
            indici_ok=find(isfinite(minimi));
            tabella_corrispondenza_bacini=NaN(size(coord_foci_idraulico,1),2);
            tabella_corrispondenza_bacini(indici_ok,2)=indici_ottimo(indici_ok);
            
        end
        
        
        function [tabella_corrispondenza_aste,ReticoloDati]=searchAsteSimili(obj,ReticoloDati,bacini_corrispondenti)
            
            % [tabella_corrispondenza_aste,ReticoloDati]=searchAsteSimili(obj,ReticoloDati,bacini_corrispondenti)
            %
            % Calcolo della corrispondenza tra le aste di coppie di bacini corrispondenti.
            % INPUT
            %   ReticoloDati = reticolo con il quale costruire l'assegnazione
            %   bacini_corrispondenti = matrice n x 2 con le coppie di bacini corrispondenti
            % OUTPUT
            %   tabella_corrispondenza_aste = matrice n x 2, colonna 1; indici delle aste idrauliche, colonna 2: indici delle aste idrologiche (eventualmente dinamiche) corrisponenti
            %   ReticoloDati = reticolo aggiornato (eventualmente con aste dinamiche operative)
            
            
            % Inizializzazione tabella
            tabella_corrispondenza_aste=NaN(length(vertcat(obj.bacini(bacini_corrispondenti(:,1)).aste)),2);
            k_aste_idraulico=0;

            
            % FIGURA CONTROLLO
            figure; hold on;
            RiverNetwork.figureScreenRatio(ReticoloDati.VEC.coord_rami);
            
            % Inizializzazione struttura nuove aste del bacino idrologico corrente
            aste_idrologico_nuove=repmat(    cell2struct(cell(length(fieldnames(obj.aste)),1),fieldnames(obj.aste),1)  ,1,length(vertcat(obj.bacini(bacini_corrispondenti(:,1)).aste)));
            
            % Parametri locali
            soglia_area_rototraslazione=obj.Soglia_Area_Rototraslazione;   % Soglia area [km2] per applicare rototraslazione ai bacini idrologici
            n_max_aste_esplorazione=obj.N_Max_Aste_Esplorazione;           % Numero massimo di aste idrologiche dinamiche da esplorare
            pesi=obj.Pesi_Corrispondenza_Aste;                             % 1: peso della distanza, 2: peso dell'area drenata
            
            
            % Ciclo sulle coppie di bacini corrispondenti
            k_aste_idrologico=0;                    % Contatore nuove aste operative dei bacini idrologici
            for b=1:size(bacini_corrispondenti,1)
                
                % Inizializzaione nuove aste del bacino idrologico
                elenco_aste_bacino=[];
                
                % Eventuale rototraslazione rigida del bacino idrologico su quello idraulico
                if obj.bacini(bacini_corrispondenti(b,1)).area_km2<soglia_area_rototraslazione
                    ReticoloDati=obj.matchBacini(bacini_corrispondenti(b,1),bacini_corrispondenti(b,2),ReticoloDati);
                end
                                
                
                % Corrispondenza Aste
                if obj.Flag_Corrispondenza_Aste==1      % Corrispondenza semplice
                    
                    coord_aste_npunti_idraulico=obj.coord_aste_n_punti_interpolazione(:,obj.bacini(bacini_corrispondenti(b,1)).aste,:);
                    aree_aste_idraulico=[obj.aste(obj.bacini(bacini_corrispondenti(b,1)).aste).area_drenata_km2];
                    coord_aste_npunti_idrologico=ReticoloDati.coord_aste_n_punti_interpolazione_OP(:,ReticoloDati.bacini_OP(bacini_corrispondenti(b,2)).aste,:);
                    aree_aste_idrologico=[ReticoloDati.aste_OP(ReticoloDati.bacini_OP(bacini_corrispondenti(b,2)).aste).area_drenata_km2];
                    indici_corrispondenze_aste=RiverNetwork.corrispondenzePolilineeNpuntiAree(coord_aste_npunti_idraulico, coord_aste_npunti_idrologico, aree_aste_idraulico, aree_aste_idrologico, obj.Pesi_Corrispondenza_Aste(1), obj.Pesi_Corrispondenza_Aste(2));
                    tabella_corrispondenza_aste(k_aste_idraulico+1:k_aste_idraulico+length(aree_aste_idraulico),:)=[obj.bacini(bacini_corrispondenti(b,1)).aste(indici_corrispondenze_aste(:,1)),ReticoloDati.bacini_OP(bacini_corrispondenti(b,2)).aste(indici_corrispondenze_aste(:,2))];
                    k_aste_idraulico=k_aste_idraulico+length(aree_aste_idraulico);
                    
                elseif obj.Flag_Corrispondenza_Aste==2  % Ricerca aste dinamiche
                    
                    % calcolo degli n_max_aste_esplorazione rami idrologici più vicini al ramo sorgente di ogni asta idraulica
                    aste_idraulico=obj.bacini(bacini_corrispondenti(b,1)).aste;
                    centroidi_npunti_rami_sorgente_idraulico=squeeze(obj.coord_rami_n_punti_interpolazione(3,cellfun(@min,{obj.aste(aste_idraulico).rami}),:));  % terzo punto da monte del ramo di sorgente
                    if min(size(centroidi_npunti_rami_sorgente_idraulico))==1
                        centroidi_npunti_rami_sorgente_idraulico=centroidi_npunti_rami_sorgente_idraulico';
                    end
                    
                    if length(ReticoloDati.bacini_OP(bacini_corrispondenti(b,2)).rami)==1  % caso con un ramo solo
                        rami_testata_bacino_idrologico=ReticoloDati.bacini_OP(bacini_corrispondenti(b,2)).rami;
                    else
                        rami_testata_bacino_idrologico=intersect(ReticoloDati.bacini_OP(bacini_corrispondenti(b,2)).rami,ReticoloDati.topologia_raster_OP.indici_rami_testata);
                        if obj.Flag_Ricerca_Estesa==1   % ricerca i rami di testata nell'intorno del bacino (eventualmente anche da altri bacini)
                            [xymin,xymax]=bounds(obj.bacini(bacini_corrispondenti(b,1)).coord_contorno,1);
                            rami_testata_bacino_idrologico_aggiuntivi=intersect(find(ReticoloDati.punti_centrali_rami(:,1)>=xymin(1) & ReticoloDati.punti_centrali_rami(:,1)<=xymax(1) & ReticoloDati.punti_centrali_rami(:,2)>=xymin(2) & ReticoloDati.punti_centrali_rami(:,2)<=xymax(2)),ReticoloDati.topologia_raster_OP.indici_rami_testata);
                            rami_testata_bacino_idrologico=unique([rami_testata_bacino_idrologico(:);rami_testata_bacino_idrologico_aggiuntivi(:)]);
                        end
                    end
                    
                    
                    if length(rami_testata_bacino_idrologico)==1        % il bacino idrologico ha solo un ramo
                        
                        % Ramo di testata del bacino idrologico
                        rami_testata_bacino_idrologico=ReticoloDati.bacini_OP(bacini_corrispondenti(b,2)).rami;
                        
                        
                        % Aggiornamento della struttura delle nuove aste idrologiche
                        k_aste_idrologico=k_aste_idrologico+1;
                        elenco_aste_bacino=k_aste_idrologico;
                        aste_idrologico_nuove(k_aste_idrologico).codice=k_aste_idrologico;
                        aste_idrologico_nuove(k_aste_idrologico).rami=rami_testata_bacino_idrologico;
                        aste_idrologico_nuove(k_aste_idrologico).coord=ReticoloDati.rami_OP(rami_testata_bacino_idrologico(1)).coord;
                        aste_idrologico_nuove(k_aste_idrologico).area_drenata_km2=ReticoloDati.rami_OP(rami_testata_bacino_idrologico(1)).area_drenata_km2;
                        ReticoloDati.bacini_OP(bacini_corrispondenti(b,2)).aste=elenco_aste_bacino;
                        
                        
                        % Aggiornamento della tabella di corrispondenza delle aste idrauliche - idrologiche
                        for a=1:length(aste_idraulico)
                            k_aste_idraulico=k_aste_idraulico+1;
                            tabella_corrispondenza_aste(k_aste_idraulico,:)=[aste_idraulico(a),k_aste_idrologico];
                        end
                        
                        
                        % Aggiornamento coordinate n_punti interpolate delle aste idrologiche dinamiche
                        for a=1:length(elenco_aste_bacino)
                            ReticoloDati.coord_aste_n_punti_interpolazione_OP(:,elenco_aste_bacino(a),:)=RiverNetwork.polilinea2punti(aste_idrologico_nuove(elenco_aste_bacino(a)).coord,obj.n_punti_interpolazione);
                        end
                        
                                                
                        % FIGURA CONTROLLO
                        aste_idrauliche_bacino_corrente=aste_idraulico;
                        aste_idrologiche_bacino_corrente=tabella_corrispondenza_aste(ismember(tabella_corrispondenza_aste(:,1),aste_idrauliche_bacino_corrente),2);
                        coord_tratti=RiverNetwork.trattiConnessionePolilinee(obj.coord_aste_n_punti_interpolazione(:,aste_idrauliche_bacino_corrente,:),ReticoloDati.coord_aste_n_punti_interpolazione_OP(:,aste_idrologiche_bacino_corrente,:));
                        obj.plotReticolo(obj.bacini(bacini_corrispondenti(b,1)).rami,'b',1);
                        ReticoloDati.plotReticolo([],'r',1);
                        ReticoloDati.plotReticolo(ReticoloDati.bacini_OP(bacini_corrispondenti(b,2)).rami,'m',1,0,1);
                        for i=1:size(coord_tratti,3)
                            plot(coord_tratti(:,1,i),coord_tratti(:,2,i),'g');
                        end
                        
                        continue
                        
                    end
                    
                    % Caso generale: il bacino idrologico ha più rami
                    
                    % Ricerca dei rami di testata più vicini ai rami di monte delle aste idrauliche
                    centroidi_npunti_rami_sorgente_idrologico=squeeze(mean(ReticoloDati.coord_rami_n_punti_interpolazione_OP(:,rami_testata_bacino_idrologico,:),1));
                    if size(centroidi_npunti_rami_sorgente_idrologico,2)==1
                        centroidi_npunti_rami_sorgente_idrologico=centroidi_npunti_rami_sorgente_idrologico';
                    end
                    [~,indici_rami_sorgente_vicini]=sort(pdist2(centroidi_npunti_rami_sorgente_idrologico,centroidi_npunti_rami_sorgente_idraulico));  % ordinamento per area drenata
                    n_aste_esplorazione=min(length(rami_testata_bacino_idrologico),n_max_aste_esplorazione);
                    indici_rami_sorgente_vicini=rami_testata_bacino_idrologico(indici_rami_sorgente_vicini(1:n_aste_esplorazione,:));
                    
                    
                    % Inizializzazione della generazione delle aste idrologiche dinamiche
                    memo_sequenze_esplorate=[];
                    aree_aste_idraulico=[obj.aste(aste_idraulico).area_drenata_km2];
                    centroidi_npunti_rami_valle_aste=squeeze(obj.coord_rami_n_punti_interpolazione(end-2,cellfun(@max,{obj.aste(aste_idraulico).rami}),:));  % terzo punto da valle del ramo
                    if min(size(centroidi_npunti_rami_valle_aste))==1
                        centroidi_npunti_rami_valle_aste=centroidi_npunti_rami_valle_aste';
                    end
                    
                    
                    % Caratteristiche delle aste idrauliche
                    lunghezze_aste_idraulico=NaN(length(aste_idraulico),1);
                    coord_punti_aste_idraulico=NaN(obj.n_punti_interpolazione,length(aste_idraulico),2);
                    
                    
                    % Ciclo di ricerca dell'asta idrologica dinamica più simile per ogni asta del bacino idraulico
                    for a=1:length(aste_idraulico)
                        
                        % Calcolo lunghezza dell'asta del bacino idraulico
                        if size(obj.aste(aste_idraulico(a)).coord,1)>1
                            lunghezze_aste_idraulico(a)=RiverNetwork.lunghezzaPolilinea(obj.aste(aste_idraulico(a)).coord);
                        else
                            lunghezze_aste_idraulico(a)=(obj.dx+obj.dy)/2;
                        end
                        
                        % Coordinate dell'asta idraulica interpolate su n punti
                        coord_punti_aste_idraulico(:,a,:)=RiverNetwork.polilinea2punti(obj.aste(aste_idraulico(a)).coord,obj.n_punti_interpolazione);
                        
                        % Costruzione delle n_max_aste_esplorazione potenziali sequenze di rami idrologici vicine all'asta idraulica
                        [sequenze_rami_idrologico,memo_sequenze_esplorate]=RiverNetwork.percorsoRamiValle(ReticoloDati.matrice_confluenze_OP, -sort(-indici_rami_sorgente_vicini(:,a)), memo_sequenze_esplorate);
                        
                        % Taglio delle n_max_aste_esplorazione sequenze di rami idrologici fino al ramo idrologico più vicino alla chiusura dell'asta idraulica
                        coord_polilinee_idrologico=cell(n_aste_esplorazione,1);
                        aree_polilinee_idrologico=NaN(n_aste_esplorazione,1);
                        coord_punti_polilinee_idrologico=NaN(obj.n_punti_interpolazione,n_aste_esplorazione,2);
                        % Ciclo sulle aste di esplorazione
                        for r=1:n_aste_esplorazione
                            
                            % costruzione e minimizzazione del funzionale di costo
                            errori_aree_adim=abs(([ReticoloDati.rami_OP(sequenze_rami_idrologico{r}).area_drenata_km2]-aree_aste_idraulico(a)))/aree_aste_idraulico(a);
                            errori_distanze_adim= sqrt( sum( (  ReticoloDati.punti_centrali_rami_OP(sequenze_rami_idrologico{r},:) - ones(length(sequenze_rami_idrologico{r}),1)*centroidi_npunti_rami_valle_aste(a,:)).^2 ,2))./lunghezze_aste_idraulico(a);
                            [~,indice_minimo]=min(errori_distanze_adim(:)*pesi(1)+errori_aree_adim(:)*pesi(2));
                            sequenze_rami_idrologico{r}=sequenze_rami_idrologico{r}(1:indice_minimo);
                            coord_polilinee_idrologico{r}=ReticoloDati.coordSequenzaRami(sequenze_rami_idrologico{r},1);
                            aree_polilinee_idrologico(r)=ReticoloDati.rami_OP(sequenze_rami_idrologico{r}(end)).area_drenata_km2;
                            coord_punti_polilinee_idrologico(:,r,:)=RiverNetwork.polilinea2punti(coord_polilinee_idrologico{r},obj.n_punti_interpolazione);
                            
                        end
                        
                        % Asta idrologica dinamica più vicina all'asta idraulica corrente
                        indici_aste_corrispondenti=RiverNetwork.corrispondenzePolilineeNpuntiAree(coord_punti_aste_idraulico(:,a,:), coord_punti_polilinee_idrologico, aree_aste_idraulico(a), aree_polilinee_idrologico, pesi(1), pesi(2));
                        
                        % Generazione della struttura dati per la nuova asta idrologica
                        k_aste_idrologico=k_aste_idrologico+1;
                        elenco_aste_bacino=[elenco_aste_bacino;k_aste_idrologico]; %#ok<AGROW>
                        aste_idrologico_nuove(k_aste_idrologico).codice=k_aste_idrologico;
                        aste_idrologico_nuove(k_aste_idrologico).rami=sequenze_rami_idrologico{indici_aste_corrispondenti(2)}(end:-1:1);
                        aste_idrologico_nuove(k_aste_idrologico).coord=coord_polilinee_idrologico{indici_aste_corrispondenti(2)};
                        aste_idrologico_nuove(k_aste_idrologico).area_drenata_km2=aree_polilinee_idrologico(indici_aste_corrispondenti(2));
                        
                        % Aggiornamento della tabella di corrispondenza delle aste idrauliche - idrologiche
                        k_aste_idraulico=k_aste_idraulico+1;
                        tabella_corrispondenza_aste(k_aste_idraulico,:)=[aste_idraulico(a),k_aste_idrologico];
                        
                        
                    end
                    
                    
                    % Assegnazione delle aste idrologiche dinamiche al bacino operativo corrente
                    ReticoloDati.bacini_OP(bacini_corrispondenti(b,2)).aste=elenco_aste_bacino;
                    
                    % Aggiornamento coordinate n_punti interpolate delle aste idrologiche dinamiche
                    for a=1:length(elenco_aste_bacino)
                        ReticoloDati.coord_aste_n_punti_interpolazione_OP(:,elenco_aste_bacino(a),:)=RiverNetwork.polilinea2punti(aste_idrologico_nuove(elenco_aste_bacino(a)).coord,obj.n_punti_interpolazione);
                    end
                    
                end
                
                
                % FIGURA CONTROLLO
                aste_idrauliche_bacino_corrente=aste_idraulico;
                aste_idrologiche_bacino_corrente=tabella_corrispondenza_aste(ismember(tabella_corrispondenza_aste(:,1),aste_idrauliche_bacino_corrente),2);
                coord_tratti=RiverNetwork.trattiConnessionePolilinee(obj.coord_aste_n_punti_interpolazione(:,aste_idrauliche_bacino_corrente,:),ReticoloDati.coord_aste_n_punti_interpolazione_OP(:,aste_idrologiche_bacino_corrente,:));
                obj.plotReticolo(obj.bacini(bacini_corrispondenti(b,1)).rami,'b',1);
                ReticoloDati.plotReticolo([],'r',1);
                ReticoloDati.plotReticolo(ReticoloDati.bacini_OP(bacini_corrispondenti(b,2)).rami,'m',2,0,1);
                for i=1:size(coord_tratti,3)
                    plot(coord_tratti(:,1,i),coord_tratti(:,2,i),'g');
                end
                
            end
            
            
            % Sostituzione delle aste operative idrologiche
            ReticoloDati.aste_OP=aste_idrologico_nuove;
            
            
        end
        
        
        function tabella_corrispondenza_rami=searchRamiSimili(obj,ReticoloDati,tabella_corrispondenza_aste,tabella_nuovi_indici_rami)
            
            % tabella_corrispondenza_rami=searchRamiSimili(obj,ReticoloDati,tabella_corrispondenza_aste,tabella_nuovi_indici_rami)
            %
            % Calcolo della corrispondenza tra i rami di coppie di aste corrispondenti.
            % INPUT
            %   ReticoloDati = reticolo con il quale costruire l'assegnazione
            %   tabella_corrispondenza_aste = matrice n x 2 con le coppie di aste corrispondenti
            %	tabella_nuovi_indici_rami = matrice n x 2 con gli indici dei "nuovi" rami virtuali del reticolo ReticoloDati (colonna 1) 
            %                               e i	corrispodennti indici originali (colonna 2)
            % OUTPUT
            %   tabella_corrispondenza_rami = matrice n x 2, colonna 1; indici dei rami idraulici, colonna 2: indici dei rami idrologici
        
            
            
            % Tabella completa di corrispondenza indici rami operativi - indici rami
            tabella_nuovi_indici_rami=[(1:ReticoloDati.n_rami)'*ones(1,2);tabella_nuovi_indici_rami];
            
            % Ciclo sulle aste
            tabella_corrispondenza_rami=NaN(length(vertcat(obj.aste(tabella_corrispondenza_aste(:,1)).rami)),2);
            k=0;
            for a=1:size(tabella_corrispondenza_aste,1)
                
                % Corrispondenza rami
                coord_rami_npunti_idraulico=obj.coord_rami_n_punti_interpolazione(:,obj.aste(tabella_corrispondenza_aste(a,1)).rami,:);
                aree_rami_idraulico=[obj.rami(obj.aste(tabella_corrispondenza_aste(a,1)).rami).area_drenata_km2];
                coord_rami_npunti_idrologico=ReticoloDati.coord_rami_n_punti_interpolazione_OP(:,ReticoloDati.aste_OP(tabella_corrispondenza_aste(a,2)).rami,:);
                aree_rami_idrologico=[ReticoloDati.rami_OP(ReticoloDati.aste_OP(tabella_corrispondenza_aste(a,2)).rami).area_drenata_km2];
                if length(aree_rami_idrologico)==1      % caso con UN solo ramo idrologico
                    tabella_corrispondenza_rami(k+1:k+length(aree_rami_idraulico),:)=[obj.aste(tabella_corrispondenza_aste(a,1)).rami(:), tabella_nuovi_indici_rami(ReticoloDati.aste_OP(tabella_corrispondenza_aste(a,2)).rami,1)*ones(length(aree_rami_idraulico),1) ];
                    k=k+length(aree_rami_idraulico);
                else                                    % caso generale
                    
                    % Calcolo funzione di costo per tutte le combinazioni rami asta idraulica - rami asta idrologica
                    [~,J]=RiverNetwork.corrispondenzePolilineeNpuntiAree(coord_rami_npunti_idraulico, coord_rami_npunti_idrologico, aree_rami_idraulico, aree_rami_idrologico, obj.Pesi_Corrispondenza_Rami(1), obj.Pesi_Corrispondenza_Rami(2));
                    
                    % costruzione della matrice dei rami idrologici più vicini a ogni ramo idraulico
                    [~,indici_sort]=sort(J);
                    indici_sort=indici_sort+ones(length(aree_rami_idrologico),1)*(0:length(aree_rami_idrologico):(length(aree_rami_idraulico)-1)*length(aree_rami_idrologico));
                    matrice_rami_idrologici_ordinati=single(ReticoloDati.aste_OP(tabella_corrispondenza_aste(a,2)).rami(:))*ones(1,length(aree_rami_idraulico));
                    matrice_rami_idrologici_ordinati=tabella_nuovi_indici_rami(matrice_rami_idrologici_ordinati(indici_sort));
                    
                    % Ciclo sui rami idraulici
                    soglia=Inf;
                    for r=1:size(matrice_rami_idrologici_ordinati,2)
                        k=k+1;
                        tabella_corrispondenza_rami(k,:)=[obj.aste(tabella_corrispondenza_aste(a,1)).rami(r), matrice_rami_idrologici_ordinati(find(matrice_rami_idrologici_ordinati(:,r)<=soglia,1),r)];
                        soglia=min(soglia,tabella_corrispondenza_rami(k,2));
                    end
                    
                end
                
            end
            
            
        end
        
        
        function ReticoloDati=matchBacini(obj,indice_bacino_idraulico,indice_bacino_idrologico,ReticoloDati)
            
            % ReticoloDati=matchBacini(obj,indice_bacino_idraulico,indice_bacino_idrologico,ReticoloDati)
            % 
            % Rototrasla il bacino idrologico in modo da corrispondere il più possibile al corrispettivo bacino idraulico.
            % INPUT
            %   indice_bacino_idraulico = indice del bacino idraulico corrente
            %   indice_bacino_idrologico = indice del bacino idrologico corrispondente
            %	ReticoloDati = reticolo con il quale costruire l'assegnazione
            % OUTPUT
            %   ReticoloDati = reticolo aggiornato
            
            
            % Rami dei due bacini
            rami_bacino_idraulico=obj.bacini(indice_bacino_idraulico).rami;
            rami_bacino_idrologico=ReticoloDati.bacini_OP(indice_bacino_idrologico).rami;
            
            % Vettori coordinate dei rami dei bacini idrologico e idraulico
            coord_rami_idraulico=obj.getCoordSetRami(rami_bacino_idraulico,2);
            coord_rami_idrologico=ReticoloDati.getCoordSetRami(rami_bacino_idrologico,2,2);
            coord_rami_idraulico(isnan(coord_rami_idraulico(:,1)),:)=[];
            coord_rami_idrologico(isnan(coord_rami_idrologico(:,1)),:)=[];
            
            % parametri per la rototraslazione ottimale
            if size(coord_rami_idrologico,1)==1 || size(coord_rami_idraulico,1)==1  % caso con un solo ramo di un solo punto
                
                foce_bacino_idrologico=ReticoloDati.bacini_OP(indice_bacino_idrologico).foce;
                foce_bacino_idraulico=obj.bacini_OP(indice_bacino_idraulico).foce;
                distanza_foci=foce_bacino_idraulico-foce_bacino_idrologico;
                parametri_ottimi=[distanza_foci,0];
                
            else                                                                    % caso generale
                
                % Angolo tra le aste principali del bacino idrologico e del bacino idraulico
                angolo_aste_principali=obj.angoloPolilinee(obj.aste(obj.bacini(indice_bacino_idraulico).aste(1)).coord,ReticoloDati.aste_OP(ReticoloDati.bacini_OP(indice_bacino_idrologico).aste(1)).coord);
                
                % Media delle distanze tra le foci e tra i centroidi del bacino idrologico e del bacino idraulico
                distanza_foci_centroidi=( obj.bacini(indice_bacino_idraulico).foce - ReticoloDati.bacini_OP(indice_bacino_idrologico).foce + ...
                                          obj.bacini(indice_bacino_idraulico).centroide - ReticoloDati.bacini_OP(indice_bacino_idrologico).centroide )/2;
                % Parametri iniziali della rototraslazione
                parametri_rototrasl_0=[distanza_foci_centroidi angolo_aste_principali];
                % Configurazione dell'algoritmo di ricerca
                limiti_parametri_rototrals=[-Inf -Inf -Inf;...
                                             Inf  Inf  Inf];
                tolleranza=0.01*max([obj.dx,obj.dy,ReticoloDati.dx,ReticoloDati.dy]);
                parametri_algoritmo_minimizzazione=optimoptions('fmincon','Display','none','Algorithm','sqp','TolX',tolleranza);
                
                % Ricerca della rototraslazione ottimi
                funzione_costo = @(parametri_rototrasl) obj.costoDistanzaBacini(parametri_rototrasl,coord_rami_idraulico,coord_rami_idrologico,ReticoloDati.bacini_OP(indice_bacino_idrologico).foce);
                parametri_ottimi=fmincon(funzione_costo,parametri_rototrasl_0,[],[],[],[],limiti_parametri_rototrals(1,:),limiti_parametri_rototrals(2,:),[],parametri_algoritmo_minimizzazione);
                
            end
                        
            
            % Aggiornamento delle coordinate di tutti i rami del bacino idrologico rototraslato
            rami_bacino_idrologico=ReticoloDati.bacini_OP(indice_bacino_idrologico).rami;
            foce_bacino_idrologico=ReticoloDati.bacini_OP(indice_bacino_idrologico).foce;
            for r=1:length(rami_bacino_idrologico)
                ReticoloDati.rami_OP(rami_bacino_idrologico(r)).coord=obj.rototraslazionePolilinee(ReticoloDati.rami_OP(rami_bacino_idrologico(r)).coord,parametri_ottimi(1:2),parametri_ottimi(3),foce_bacino_idrologico);
                indici_ramo=find(ReticoloDati.VEC_OP.codici_rami==rami_bacino_idrologico(r));
                ReticoloDati.VEC_OP.coord_rami(indici_ramo(1:end-1),:)=ReticoloDati.rami_OP(rami_bacino_idrologico(r)).coord;
            end
            
            % Aggiornamento delle coordinate di tutte le aste del bacino idrologico rototraslato
            aste_bacino_idrologico=ReticoloDati.bacini_OP(indice_bacino_idrologico).aste;
            for a=1:length(aste_bacino_idrologico)
                coord_asta=ReticoloDati.getCoordSetRami(ReticoloDati.aste_OP(aste_bacino_idrologico(a)).rami(end:-1:1),2,2);
                coord_asta(isnan(coord_asta(:,1)),:)=[];
                diff_coord_asta=diff(coord_asta,1,1);
                coord_asta(all(diff_coord_asta'==0),:)=[];
                ReticoloDati.aste_OP(aste_bacino_idrologico(a)).coord=coord_asta;
            end
            
            
            % Aggiornamento coordinate rami interpolate su n_punti_interpolazione punti
            for r=1:length(rami_bacino_idrologico)
                ReticoloDati.coord_rami_n_punti_interpolazione_OP(:,rami_bacino_idrologico(r),:)=RiverNetwork.polilinea2punti(ReticoloDati.rami_OP(rami_bacino_idrologico(r)).coord,obj.n_punti_interpolazione);
            end
            
            % Aggiornamento coordinate aste interpolate su n_punti_interpolazione punti
            for a=1:length(aste_bacino_idrologico)
                ReticoloDati.coord_aste_n_punti_interpolazione_OP(:,aste_bacino_idrologico(a),:)=obj.polilinea2punti(ReticoloDati.aste_OP(aste_bacino_idrologico(a)).coord,obj.n_punti_interpolazione);
            end
                        
            
        end
        
        
        function costo=costoDistanzaBacini(obj,parametri_rototrasl,coord_rami_idraulico,coord_rami_idrologico,coord_polo)
            
            % costo=costoDistanzaBacini(obj,parametri_rototrasl,coord_rami_idraulico,coord_rami_idrologico,coord_polo)
            %
            % Funzionale di costo per il confronto di dua bacini.
            % INPUT
            %   parametri_rototrasl = parametri della rototralsazione del bacino idrologico
            %   ,coord_rami_idraulico = coordinate di tutti i rami del bacino idraulico
            %   coord_rami_idrologico = coordinate di tutti i rami del bacino idrologico
            %   coord_polo = coordinate del polo di rotazione
            % OUTPUT
            %   costo = valore del funzionale di costo per la specifica rototraslazione del bacino idrologico
            
            
            coord_rami_idrologico_rototraslate=obj.rototraslazionePolilinee(coord_rami_idrologico,parametri_rototrasl(1:2),parametri_rototrasl(3),coord_polo);
            distanze=nanmin(obj.DistanzePunti(coord_rami_idraulico,coord_rami_idrologico_rototraslate),[],2);
            costo=mean(distanze);
            
        end
        
        
        function [obj,tabella_nuovi_indici_rami]=addBaciniAggiuntivi(obj,rami_bacini_aggiuntivi)
            
            % [obj,tabella_nuovi_indici_rami]=addBaciniAggiuntivi(obj,rami_bacini_aggiuntivi)
            %
            % Aggiunge bacini virtuali al reticolo e aggiorna tutte le property.
            % INPUT
            %   rami_bacini_aggiuntivi = rami dei bacini aggiuntivi
            % OUTPUT
            %   tabella_nuovi_indici_rami = tabella con i codici dei "nuovi" rami
            
            
            % rami dei "nuovi" bacini
            elenco_rami_aggiuntivi=unique(cell2mat(rami_bacini_aggiuntivi(:)'));
            indici_rami_aggiuntivi=length(obj.rami_OP)+(1:length(elenco_rami_aggiuntivi));
            
            
            % creazione dei "nuovi" rami
            rami_aggiuntivi=obj.rami(elenco_rami_aggiuntivi);
            obj.rami_OP=[obj.rami,rami_aggiuntivi];
            indici_nuovi_rami=num2cell(obj.rami(end).codice+(1:length(indici_rami_aggiuntivi)));
            [obj.rami_OP(obj.n_rami+1:obj.n_rami+length(elenco_rami_aggiuntivi)).codice]=deal(indici_nuovi_rami{:});
            tabella_nuovi_indici_rami=[elenco_rami_aggiuntivi(:),(obj.n_rami+(1:length(elenco_rami_aggiuntivi)))'];
            
            
            % creazione delle variabili vettoriali dei "nuovi" rami
            coord_rami_aggiuntivi={rami_aggiuntivi.coord};
            temp=reshape([coord_rami_aggiuntivi;repmat({NaN(1,2)},1,numel(coord_rami_aggiuntivi))],1,[]);
            coord_rami_aggiuntivi_vettore=vertcat(temp{:});
            n_punti_rami=cellfun(@(x) size(x,1), coord_rami_aggiuntivi);
            id_rami=arrayfun(@(i,n) repmat(i,n,1), (1:numel(coord_rami_aggiuntivi))', n_punti_rami(:)+1, 'UniformOutput', false);
            id_rami=cellfun(@(x) [x], id_rami,'UniformOutput',false); %#ok<NBRAK>
            codici_rami_aggiuntivi_vettore=vertcat(id_rami{:});
            codici_rami_aggiuntivi_vettore(isfinite(codici_rami_aggiuntivi_vettore))=codici_rami_aggiuntivi_vettore(isfinite(codici_rami_aggiuntivi_vettore))+obj.n_rami;
            % Aggiornamento variabili VEC_OP
            obj.VEC_OP.coord_rami=[obj.VEC_OP.coord_rami;coord_rami_aggiuntivi_vettore];
            obj.VEC_OP.codici_rami=[obj.VEC_OP.codici_rami;codici_rami_aggiuntivi_vettore];
            obj.punti_centrali_rami_OP=[obj.punti_centrali_rami_OP;obj.punti_centrali_rami(tabella_nuovi_indici_rami(:,1),:)];
            % Aggiornamento rami interpolati su n punti
            coord_rami_n_punti_interpolazione_aggiuntivi=NaN(obj.n_punti_interpolazione,length(rami_aggiuntivi),2);
            for r=1:length(rami_aggiuntivi)
                coord_rami_n_punti_interpolazione_aggiuntivi(:,r,:)=RiverNetwork.polilinea2punti(coord_rami_aggiuntivi{r},obj.n_punti_interpolazione);
            end
            obj.coord_rami_n_punti_interpolazione_OP=cat(2,obj.coord_rami_n_punti_interpolazione_OP,coord_rami_n_punti_interpolazione_aggiuntivi);
            % Aggiornamento rami di testata operativi
            indici_rami_testata_nuovi=find(ismember(tabella_nuovi_indici_rami(:,1),obj.topologia_raster.indici_rami_testata));
            obj.topologia_raster_OP.indici_rami_testata=[obj.topologia_raster_OP.indici_rami_testata;tabella_nuovi_indici_rami(indici_rami_testata_nuovi,2)]; %#ok<FNDSB>
            
            % Estensione della matrice delle confluenze
            C=sparse(zeros(length(obj.rami_OP)));
            C(1:obj.n_rami,1:obj.n_rami)=obj.topologia_raster.matrice_confluenze;
            for i=1:size(tabella_nuovi_indici_rami,1)
                riga_OLD=C(tabella_nuovi_indici_rami(i,1),:);
                if sum(riga_OLD)>0
                    C(tabella_nuovi_indici_rami(i,2),tabella_nuovi_indici_rami(ismember(tabella_nuovi_indici_rami(:,1),find(riga_OLD)),2))=1; %#ok<SPRIX>
                end
            end
            obj.matrice_confluenze_OP=sparse(C);
                        
            
            % creazione dei "nuovi" bacini
            bacini_aggiuntivi=repmat(obj.bacini(1),1,length(rami_bacini_aggiuntivi));
            indici_nuovi_bacini=num2cell(obj.bacini(end).codice+(1:length(rami_bacini_aggiuntivi)));
            [bacini_aggiuntivi(1:length(rami_bacini_aggiuntivi)).codice]=deal(indici_nuovi_bacini{:});
            contorni_bacini_aggiuntivi=obj.getContorniSetRami(rami_bacini_aggiuntivi);
            for b=1:length(rami_bacini_aggiuntivi)   %obj.n_bacini+1:obj.n_bacini+length(rami_bacini_aggiuntivi)
                bacini_aggiuntivi(b).rami=tabella_nuovi_indici_rami(ismember(tabella_nuovi_indici_rami(:,1),rami_bacini_aggiuntivi{b}),2);
                bacini_aggiuntivi(b).foce=obj.rami_OP(bacini_aggiuntivi(b).rami(end)).coord(end,:);
                bacini_aggiuntivi(b).area_km2=obj.rami_OP(bacini_aggiuntivi(b).rami(end)).area_drenata_km2;
                bacini_aggiuntivi(b).coord_contorno=contorni_bacini_aggiuntivi(b).coord;
                bacini_aggiuntivi(b).diametro=contorni_bacini_aggiuntivi(b).diametro;
                bacini_aggiuntivi(b).centroide=contorni_bacini_aggiuntivi(b).centroide;
            end
            obj.bacini_OP=[obj.bacini,bacini_aggiuntivi];
            obj.VEC_OP.coord_foci=[obj.VEC.coord_foci;vertcat(obj.bacini_OP((obj.n_bacini+1):(obj.n_bacini+length(rami_bacini_aggiuntivi))).foce)];
            
            
            % Calcolo delle aste dei "nuovi" bacini
            aste_aggiuntive=cell2struct(cell(length(fieldnames(obj.aste)),1),fieldnames(obj.aste),1);
            [aste_bacini_aggiuntivi,coord_aste_bacini_aggiuntivi,aree_aste_bacini_aggiuntivi]=deal(cell(length(bacini_aggiuntivi),1));
            k=0;
            codici_bacini_aste_aggiuntive=[];
            for b=1:length(bacini_aggiuntivi)
                [aste_bacini_aggiuntivi{b},coord_aste_bacini_aggiuntivi{b},aree_aste_bacini_aggiuntivi{b}]=RiverNetwork.reticolo2aste( bacini_aggiuntivi(b).rami, [obj.rami_OP(:).area_drenata_km2] , obj.getCoordSetRami(1:length(obj.rami_OP),1,2), obj.matrice_confluenze_OP);
                na=length(aste_bacini_aggiuntivi{b});
                for a=k+1:k+na
                    aste_aggiuntive(a).codice=obj.codice_dominio+length(obj.aste)+a;
                    aste_aggiuntive(a).rami=aste_bacini_aggiuntivi{b}{a-k};
                    aste_aggiuntive(a).coord=coord_aste_bacini_aggiuntivi{b}{a-k};
                    aste_aggiuntive(a).area_drenata_km2=aree_aste_bacini_aggiuntivi{b}{a-k};
                end
                codici_bacini_aste_aggiuntive=[codici_bacini_aste_aggiuntive;obj.n_bacini+b*ones(na,1)]; %#ok<AGROW>
                k=k+na;
                obj.bacini_OP(obj.n_bacini+b).aste=length(obj.aste)+find(codici_bacini_aste_aggiuntive==(obj.n_bacini+b));
            end
            obj.aste_OP=[obj.aste,aste_aggiuntive];
            
            % Aggiornamento variabili vettoriali delle aste dei "nuovi" bacini
            coord_aste_n_punti_interpolazione_aggiuntivi=NaN(obj.n_punti_interpolazione,length(aste_aggiuntive),2);
            for a=1:length(aste_aggiuntive)
                coord_aste_n_punti_interpolazione_aggiuntivi(:,r,:)=obj.polilinea2punti(aste_aggiuntive(a).coord,obj.n_punti_interpolazione);
            end
            obj.coord_aste_n_punti_interpolazione_OP=cat(2,obj.coord_aste_n_punti_interpolazione,coord_aste_n_punti_interpolazione_aggiuntivi);
            
            
        end
        
        
        function v=polilinea2vettoreDirezionale(obj,coord_polilinea)
            
            % v=polilinea2vettoreDirezionale(obj,coord_polilinea)
            %
            % Fitta un versore direzionale su una polilinea.
            % INPUT
            %   coord_polilinea = matrice n x 2 con le coordinate della polilinea
            % OUTPUT
            %   v = componenti del versore direzionale
            
            
            n_angoli=size(obj.x_vettori_radiali,2);
            coord_polilinea(isnan(coord_polilinea(:,1)) | isnan(coord_polilinea(:,2)),:)=[];
            coord_polilinea=coord_polilinea-ones(size(coord_polilinea,1),1)*coord_polilinea(end,:);
            coord_polilinea=coord_polilinea/sqrt(coord_polilinea(1,1).^2+coord_polilinea(1,2).^2);    % Coordinate "adimensionali" della polilinea
            coord_punti_polilinea=obj.polilinea2punti(coord_polilinea,obj.n_punti_interpolazione);
            distanze=nansum((coord_punti_polilinea(:,1)*ones(1,n_angoli)-obj.x_vettori_radiali).^2+(coord_punti_polilinea(:,2)*ones(1,n_angoli)-obj.y_vettori_radiali).^2);
            [~,angolo_polilinea]=min(distanze);
            v=[cos(deg2rad(angolo_polilinea)),sin(deg2rad(angolo_polilinea))];
            
        end
        
        
        function [Jdist,Jaree]=getDistanzeRamiRami(obj,ReticoloDati)
            
            % [Jdist,Jaree]=getDistanzeRamiRami(obj,ReticoloDati)
            %
            % Calcola le componenti della distanza tra i rami di due reticoli.
            % INPUT
            %   ReticoloDati = altro reticolo rispetto ai cui rami calcolare le distanze
            % OUTPUT
            %   Jdist = distanza adimensionale tra le coordinate dei rami
            %   Jaree = differenza adimensionale tra le aree drenate dei rami
            
            
            Distanze_punti_rami=RiverNetwork.DifferenzeCoordinateReticoli(single(obj.coord_rami_n_punti_interpolazione),single(ReticoloDati.coord_rami_n_punti_interpolazione));
            Differenze_aree_rami=(obj.aree_monte_rami_km2(:)*ones(1,ReticoloDati.n_rami)-ones(obj.n_rami,1)*(ReticoloDati.aree_monte_rami_km2(:)'))./(ones(obj.n_rami,1)*(ReticoloDati.aree_monte_rami_km2(:)'));
            
            % Distanze tra i rami
            Distanze_rami=mean(Distanze_punti_rami,3);
            
            % Funzioni di costo
            Jdist=Distanze_rami./max(Distanze_rami,[],2);
            Jaree=Differenze_aree_rami./max(Differenze_aree_rami,[],2);
            
        end
        
        
        function [coord_set_rami,codici_rami]=getCoordSetRami(obj,rami,flag_output,flag_OP)
            
            % [coord_set_rami,codici_rami]=getCoordSetRami(obj,rami,flag_output,flag_OP)
            %
            % Estrae le coordinate di un set di rami.
            % INPUT
            %   rami = indici (NON codici) dei rami
            %   flag_ouput = 1 (Default): estrae un cell array di coordinate dei rami, 2: estrae una singola matrice di coordinate con i rami separati da NaN
            %   flag_OP = 1 (Default): usa le coordinate standard, 2: usa le coordinate OP
            % OUTPUT
            %   coord_set_rami = matrice o cell array con le coordinate dei punti di ogni ramo
            %   codici_rami = vettore con gli indici dei rami
            
            
            % Controllo input
            if nargin==2
                flag_output=1;
                flag_OP=1;
            elseif nargin==3
                flag_OP=1;
            end
            if flag_OP==1
                rami_correnti=obj.rami(rami);
            else
                rami_correnti=obj.rami_OP(rami);
            end
            
            
            if flag_output==1        % caso cell array
                coord_set_rami={rami_correnti(:).coord}';
                codici_rami=rami;
            else                     % caso matrice
                coord={(rami_correnti(:).coord)}';
                npunti_rami=cellfun(@size,coord,num2cell(ones(length(coord),1)));
                codici_rami=NaN(sum(npunti_rami)+length(coord),1);
                coord_set_rami=NaN(sum(npunti_rami)+length(coord),2);
                k=0;
                for r=1:length(coord)
                    coord_set_rami(k+1:k+npunti_rami(r),:)=coord{r};
                    codici_rami(k+1:k+npunti_rami(r)+1)=rami(r);
                    k=k+npunti_rami(r)+1;
                end
            end
            
        end
        
        
        function gusci_rami=getContorniSetRami(obj,rami_bacini)
            
            % gusci_rami=getContorniSetRami(obj,rami_bacini)
            %
            % Calcola le coordinate del contorno e altre caratteristiche di un insieme di rami.
            % INPUT
            %   rami_bacini = cell array contenente in ogni elemento un insieme di rami di cui calcolare il contorno
            % OUTPUT
            %   gusci_rami = struct con i seguenti campi:
            %                   coord_guscio : coordinate del guscio convesso dell'insieme dei rami
            %                   coord : coordinate del contorno dell'insieme dei rami (riproduce approssimativamente la "forma" dell'insieme dei rami)
            %                   area : area del contorno
            %                   centroide : coordinate del centroide dell'insieme dei rami
            %                   diametro : diametro dell'insieme dei rami
            
            
            gusci_rami=struct('coord_guscio',[],'coord',[],'area',[],'centroide',[],'diametro',[]);
            for b=1:length(rami_bacini)
                
                coord_punti_bacino=cell2mat(obj.getCoordSetRami(rami_bacini{b},1,2));
                try
                    indici_hull=convhull(coord_punti_bacino);
                    indici_boundary=boundary(coord_punti_bacino);
                    coord_guscio=coord_punti_bacino(indici_hull,:);
                    coord_contorno=coord_punti_bacino(indici_boundary,:);
                    diametro=2*mean(sqrt((coord_contorno(:,1)-coord_contorno(1)).^2+(coord_contorno(:,2)-coord_contorno(2)).^2));
                    area_guscio=polyarea(coord_contorno(:,1),coord_contorno(:,2));
                catch
                    coord_guscio=coord_punti_bacino;
                    coord_contorno=coord_punti_bacino;
                    diametro=sqrt((coord_punti_bacino(1,1)-coord_punti_bacino(end,1))^2+(coord_punti_bacino(1,2)-coord_punti_bacino(end,2))^2);
                    if diametro>0
                        area_guscio=diametro*mean([obj.dx,obj.dy]);
                    elseif diametro==0
                        area_guscio=obj.area_cella;
                        diametro=(obj.dx+obj.dx)/2;
                    end
                end
                gusci_rami(b).coord_guscio=coord_guscio;
                gusci_rami(b).coord=coord_contorno;
                gusci_rami(b).area=area_guscio;
                gusci_rami(b).centroide=mean(coord_punti_bacino,1);
                gusci_rami(b).diametro=diametro;
                
            end
                        
        end
        
        
        function perc_bacini_interni=PercIntersezioneBacini(obj,coord_contorno)
            
            % perc_bacini_interni=PercIntersezioneBacini(obj,coord_contorno)
            %
            % Per ogni bacino calcola la percentuale di intersezione con il contorno.
            % INPUT
            %   coord_contorno = coordinate del contorno
            % OUTPUT
            %   perc_bacini_interni = percentuale di intersezione di ogni bacino del reticolo con il contorno
            
            
            perc_bacini_interni=NaN(obj.n_bacini,1);
            for b=1:obj.n_bacini
                coord_bacino=obj.VEC.coord_rami(ismember(obj.VEC.codici_rami,obj.bacini(b).rami),:);
                coord_bacino(isnan(coord_bacino(:,1)),:)=[];
                punti_interni=inpolygon(coord_bacino(:,1),coord_bacino(:,2),coord_contorno(:,1),coord_contorno(:,2));
                perc_bacini_interni(b)=sum(punti_interni)/length(punti_interni);
            end
            
        end
        
        
        function errori=ToleranceError(obj, valori_riferimento, parametri_errori, valori)
            
            % errori=ToleranceError(obj, valori_riferimento, parametri_errori, valori)
            %
            % Calcola su "valori" l'errore massimo relativo in base ai valori di riferimento e
            % ai parametri (Errore minimo, errore massimo, esponente).
            % INPUT
            %   valori_riferimento = valori massimo e minimo ai quali assegnare l'errore massimo e minimo
            %   parametri_errori = parametri degli errori, 1: errore minimo, 2: errore massimo, 3: esponente della legge di variazione
            %   valori = valori sui quali calcolare l'errore di tolleranza
            
            errori=min(parametri_errori(2),max(parametri_errori(1),obj.ExpModulation(valori_riferimento(1),valori_riferimento(2),parametri_errori(1),parametri_errori(2),parametri_errori(3),valori)));
            
        end
        
        
        function coord_polilinea=coordSequenzaRami(obj,sequenza_rami,flag_OP)
            
            % coord_polilinea=coordSequenzaRami(obj,sequenza_rami,flag_OP)
            %
            % Calcola le coordinate di una sequenza continua di rami.
            % INPUT
            %   sequenza_rami = elenco degli indici (NON codici) dei rami di una sequenza continua
            %   flag_OP = 0: usa i valori standard, 1: usa i valori operativi
            % OUTPUT
            %   coord_polinea = matrice con le coordinate di tutti i punti della polilinea
            
            % Controllo input
            if nargin==2
                flag_OP=0;
            end
            
            % Calcolo delle coordinate di tutti i punti della polilinea, senza punti ripetuti
            if flag_OP==0
                coord_polilinea=obj.VEC.coord_rami(ismember(obj.VEC.codici_rami,sequenza_rami),:);
            elseif flag_OP==1
                coord_polilinea=obj.VEC_OP.coord_rami(ismember(obj.VEC_OP.codici_rami,sequenza_rami),:);
            end
            coord_polilinea(isnan(coord_polilinea(:,1)),:)=[];
            differenze=diff(coord_polilinea,1,1);
            coord_polilinea(differenze(:,1)==0 & differenze(:,2)==0,:)=[];  % eliminazione di punti ripetuti
            
        end
        
        
        function angolo=angoloPolilinee(obj,coord_polilinea1,coord_polilinea2)
            
            % angolo=angoloPolilinee(obj,coord_polilinea1,coord_polilinea2)
            % 
            % Calcola l'angolo tra due polilinee (angolo tra i versori corrispondenti).
            % INPUT
            %   coord_polilinea1 = coordinate della prima polilinea
            %   coord_polilinea1 = coordinate della seconda polilinea
            % OUPUT
            %   angolo = angolo tra le due polilinee [rad]
            
            
            vettore_polilinea1=obj.polilinea2vettoreDirezionale(coord_polilinea1);
            vettore_polilinea2=obj.polilinea2vettoreDirezionale(coord_polilinea2);
            angolo=obj.vettori2angolo(vettore_polilinea2,vettore_polilinea1);
            if abs(angolo-pi)<0.2
                angolo=pi-angolo;
            end
            
        end
                
       
        
    end
    
    
    methods (Static)
        
        
        
        function mappa_aree_competenza=areeCompetenza(puntatori,aree_monte,sezioni,P,flag_fill,nome_file_out)

            % mappa_aree_competenza=areeCompetenza(puntatori,aree_monte,sezioni,P,flag_fill,nome_file_out)
            % 
            % Calcola le aree di competenza di un insieme di sezionidate la mappa dei puntatori e la mappa delle aree drenate,
            % ed eventualmente scrive la mappa su un file.
            % INPUT
            %   puntatori = file con la mappa dei puntatori idrologici (o struct con campi 'mappa','x','y')
            %   aree_monte = file con la mappa delle aree drenate (o struct con campi 'mappa','x','y')
            %   sezioni = matrice n x 2 o n x 3 con le coordinate delle sezioni, nell'eventuale terza colonna 
            %             ci sono i codici che verranno assegnati alle aree di competenza
            %   P = matrice 3 x 3 con i codici dei puntatori idrologici (OPZIONALE, NON ATTIVO)
            %   flag_fill = (OPZIONALE) 0: lascia le aree invariate (DEFAULT), 1: riempie le celle non assegnate del dominio con nearest neighbor dei valori delle aree di competenza assegnate
            %   nome_file_out = (OPZIONALE) nome del file raster (senza estenzione) in cui scrivere la mappa delle aree di competenza 
            %                   (se vuoto o assente non viene scritto nessun file)
            % OUTPUT
            %   mappa_aree_competenza = mappa dei codici delle aree di competenza (progressivo corrispondente alle sezioni)

            
            % Controllo input
            if nargin==3
                P=RiverNetwork.PUNTATORI;                           % direzioni di drenaggio standard
                flag_fill=0;
                nome_file_out='';
            elseif nargin==4
                flag_fill=0;
                nome_file_out='';
            elseif nargin==5
                nome_file_out='';
            end
            if isempty(P)
                P=RiverNetwork.PUNTATORI;                           % direzioni di drenaggio standard
            end
            if isempty(flag_fill)
                flag_fill=0;
            end
            
            
            % Lettura raster
            if isnumeric(puntatori)
                pnt=puntatori.mappa;
                x_mappa_aree_competenza=puntatori.x;
                y_mappa_aree_competenza=puntatori.y;
            else
                [pnt,x_mappa_aree_competenza,y_mappa_aree_competenza]=RiverNetwork.letturaRaster(puntatori,'puntatori');
            end
            if isnumeric(aree_monte)
                pnt=aree_monte.mappa;
            else
                aree_monte=RiverNetwork.letturaRaster(aree_monte,'aree_monte');
            end
            [nrows,~]=size(pnt);
            dx=abs(x_mappa_aree_competenza(2)-x_mappa_aree_competenza(1)); dy=abs(y_mappa_aree_competenza(2)-y_mappa_aree_competenza(1));
            
                        
            % Coordinate sezioni
            if ~isnumeric(sezioni)
                codici_aree_competenza=[sezioni(:).codice_ramo];
                sezioni=vertcat(sezioni(:).coord_sezione);
            else
                if size(sezioni,2)==2
                    sezioni=[sezioni,(1:size(sezioni,1))'];
                end
                codici_aree_competenza=sezioni(:,3);
            end
            ij_sezioni=[ nrows-ceil((sezioni(:,2)-min(y_mappa_aree_competenza)+dy/2)/dy)+1 , ceil((sezioni(:,1)-min(x_mappa_aree_competenza)+dx/2)/dx) ];
            
            
            % Calcolo aree drenate da ogni sezione
            aree_drenate=RiverNetwork.areeDrenate(pnt,aree_monte,ij_sezioni,P,1);
            
            
            % Eliminazione aree drenate sovrapposte
            mappa_aree=zeros(size(pnt));
            maschera=double(pnt>-9000); maschera(maschera==0)=NaN; maschera(isnan(pnt))=NaN;
            L=cellfun(@length,aree_drenate);
            [ordinati,indici_sort]=sort(L); %#ok<ASGLU>
            for i=length(L):-1:1
                mappa_aree(aree_drenate{indici_sort(i)})=codici_aree_competenza(indici_sort(i));
            end
            mappa_aree(mappa_aree==0)=NaN;
            
            % Riempimento aree mancanti
            if flag_fill==1
                indici_mancanti=find(isnan(mappa_aree));
                indici_ok=find(isfinite(mappa_aree));
                xx=1:size(mappa_aree,2);
                yy=1:size(mappa_aree,1);
                [X,Y]=meshgrid(xx,yy);
                tic
                mappa_aree(indici_mancanti)=griddata(X(indici_ok),Y(indici_ok),mappa_aree(indici_ok),X(indici_mancanti),Y(indici_mancanti),'nearest');
                toc
            end
            
            
            % Mappa finale
            mappa_aree_competenza=mappa_aree.*maschera;
            % Scrittura su file
            if isempty(nome_file_out)==0
                if any(nome_file_out=='.')
                    nome_file_out=nome_file_out(1:find(nome_file_out=='.',1,'first')-1);
                end
                RiverNetwork.scritturaRaster(x_mappa_aree_competenza,y_mappa_aree_competenza,mappa_aree_competenza,[nome_file_out,'.tif']);
            end
            
        end
        
        
        
    end
    
    
    methods (Static, Access = private)
              
        
        
        function [input_RiverNetwork,flag_errore]=checkInput(input_RiverNetwork)
            
            % [input_RiverNetwork,flag_errore]=checkInput(input_RiverNetwork)
            %
            % Controllo di coerenza degli input del costruttore
            % INPUT
            %   input_RiverNetwork = struct di input del costruttore
            % OUTPUT
            %   input_RiverNetwork = struct di input del costruttore corretta
            
            % Inizializzazione
            flag_errore=0;
            
            
            % Raster
            if isstruct(input_RiverNetwork.reticolo)
                [ret,x,y]=deal(input_RiverNetwork.reticolo.mappa,input_RiverNetwork.reticolo.x,input_RiverNetwork.reticolo.y);
            else
                [ret,x,y]=RiverNetwork.letturaRaster(input_RiverNetwork.reticolo,'reticolo');
            end
            if isstruct(input_RiverNetwork.puntatori)
                pnt=input_RiverNetwork.puntatori.mappa;
            else
                [pnt,x,y]=RiverNetwork.letturaRaster(input_RiverNetwork.puntatori,'puntatori');
            end
            if isstruct(input_RiverNetwork.aree_monte)
                aree_monte=input_RiverNetwork.aree_monte.mappa;
            else
                [aree_monte,x,y]=RiverNetwork.letturaRaster(input_RiverNetwork.aree_monte,'aree_monte');
            end
            input_RiverNetwork.longitudini=x;
            input_RiverNetwork.latitudini=y;
            
            % Dimensioni raster
            if all(diff([size(ret,1),size(pnt,1),size(aree_monte,1)])==0)==0 || all(diff([size(ret,2),size(pnt,2),size(aree_monte,2)])==0)==0
                disp('ERRORE: dimensioni dei raster incoerenti.');
                flag_errore=1;
                return
            end
            if min(size(x))==1
                if length(x)~=size(ret,2) || length(y)~=size(ret,1)
                    disp('ERRORE: dimensioni delle coordinate incoerenti con le dimensioni dei raster.');
                    flag_errore=1;
                    return
                end
            else
                if all(diff([size(x,1), size(y,1)])==0)==0 || all(diff([size(x,2), size(y,2)])==0)==0
                    disp('ERRORE: dimensioni delle coordinate dei raster incoerenti.');
                    flag_errore=1;
                    return
                end
                if size(x,2)~=size(size(ret,2)) || size(x,1)~=size(size(ret,1))
                    disp('ERRORE: dimensioni delle coordinate incoerenti con le dimensioni dei raster.');
                    flag_errore=1;
                    return
                end
            end
            
            % Unità misura area
            if isfield(input_RiverNetwork,'unita_misura_area')
                if any(ismember({'cells','m2','km2'},input_RiverNetwork.unita_misura_area))==0
                    disp('WARNING: unità di area ammesse: ''cells'',''m2'',''km2'' ');
                    input_RiverNetwork.unita_misura_area='cells';
                end
            end
            if isfield(input_RiverNetwork,'unita_misura_area')==0 || isempty(input_RiverNetwork.unita_misura_area)
                input_RiverNetwork.unita_misura_area='cells';
            end
            
            % Puntatori
            if isfield(input_RiverNetwork,'codici_puntatori')==0
                input_RiverNetwork.codici_puntatori=[];
            end
            P=input_RiverNetwork.codici_puntatori;
            if isempty(P)
                P=RiverNetwork.PUNTATORI;
            end
            input_RiverNetwork.codici_puntatori=P;
            
            % Correzioni raster idroderivate
            ret(ret<0)=0;
            ret(ret>1)=1;
            ret=single(ret); pnt=single(pnt); aree_monte=single(aree_monte);
            % eliminazione valori sui bordi
            ret(:,1)=NaN; ret(1,:)=NaN; ret(:,end)=NaN; ret(end,:)=NaN;
            pnt(:,1)=NaN; pnt(1,:)=NaN; pnt(:,end)=NaN; pnt(end,:)=NaN;
            aree_monte(:,1)=NaN; aree_monte(1,:)=NaN; aree_monte(:,end)=NaN; aree_monte(end,:)=NaN;
            input_RiverNetwork.reticolo=ret;
            input_RiverNetwork.puntatori=pnt;
            input_RiverNetwork.aree_monte=aree_monte;

            % Codice del dominio
            if isfield(input_RiverNetwork,'codice_dominio')==0
                input_RiverNetwork.codice_dominio=0;
            else
                if isempty(input_RiverNetwork.codice_dominio) || input_RiverNetwork.codice_dominio<0 || (input_RiverNetwork.codice_dominio==round(input_RiverNetwork.codice_dominio))==0
                    input_RiverNetwork.codice_dominio=0;
                end
            end
            
            % Nome del dominio
            if isfield(input_RiverNetwork,'nome_dominio')==0
                input_RiverNetwork.nome_dominio='DOMINIO';
            else
                if isempty(input_RiverNetwork.nome_dominio) || isnumeric(input_RiverNetwork.nome_dominio)
                    input_RiverNetwork.codice_dominio='DOMINIO';
                end
            end
            
        end
        
        
        function [ret,pnt,aree_monte]=correzioneReticolo(ij_disconnessione_foce,ret,pnt,aree_monte,tipo_disconnessione)
            
            % [ret,pnt,aree_monte]=correzioneReticolo(ij_disconnessione_foce,ret,pnt,aree_monte,tipo_disconnessione)
            %
            % Modifica le idroderivate dopo aver inserito delle disconnnessioni nel reticolo.
            % INPUT
            %   ij_disconnessione_foce = cell array con le coordinate dei punti di disconnessione 
            %   ret = mappa del reticolo
            %   pnt = mappa dei puntatori idrologici
            %   aree_monte = mappa delle aree drenate
            %   tipo_disconnessione = vettore, possibili valori:
            %                                1: riduce l'area drenata del tratto di valle (tra disconnessione e foce)
            %                                2: elimina l'intero tratto di valle
            % OUTPUT
            %   ret = mappa del reticolo aggiornata
            %   pnt = mappa dei puntatori idrologici aggiornata
            %   aree_monte = mappa delle aree drenate aggiornata
            
            
            % Ciclo su tutte le disconnessioni
            for i=1:length(ij_disconnessione_foce)
                
                ij_disconnessione=ij_disconnessione_foce{i}(1,:);
                if size(ij_disconnessione_foce{i},1)==2
                    ij_foce=ij_disconnessione_foce{i}(2,:);
                    foce=sub2ind(size(ret),ij_foce(1),ij_foce(2));
                else
                    foce=[];
                end
                
                % identificazione di tutti i pixel a valle di questo ed elminazione dell'area drenata
                area_da_sottrarre=aree_monte(ij_disconnessione(1),ij_disconnessione(2));
                punto_disconnessione=sub2ind(size(ret),ij_disconnessione(1),ij_disconnessione(2));
                indici_tratto=RiverNetwork.percorsoReticolo(pnt,ret,punto_disconnessione,foce);
                
                % riduzione dell'area drenata
                aree_monte(indici_tratto)=max(1,aree_monte(indici_tratto)-area_da_sottrarre);
                
                % disconnessione
                if tipo_disconnessione(i)==1
                    ret(ij_disconnessione(1),ij_disconnessione(2))=0;
                    pnt(ij_disconnessione(1),ij_disconnessione(2))=0;
                elseif tipo_disconnessione(i)==2
                    ret(indici_tratto)=0;
                    pnt(indici_tratto)=0;
                end
                
            end
            
        end
        
        
        function [sequenze,memo]=percorsoRamiValle(matrice_confluenze,rami_sorgente,memo)
            
            % [sequenze,memo]=percorsoRamiValle(matrice_confluenze,rami_sorgente,memo)
            %
            % Ricostruisce le sequenza di rami a partire da un ramo di partenza fino alla foce.
            % INPUT
            %   matrice_confluenze = matrice sparsa numero_rami x numero_rami, matrice_confluenze(i,j)=1 se j confluisce in i
            %   rami_sorgente = indice o indici dei rami di partenza
            %   memo = Map delle sequenze di rami già calcolate (se esistente), usa come chiave l'indice dei rami di monte
            % OUTPUT
            %   sequenze = cell array con le sequenze dei rami fino alla foce
            %   memo = Mappa delle sequenze di rami già calcolate, usa come chiave l'indice dei rami di monte
            
            
            % Numero totale di rami
            n_rami=size(matrice_confluenze,1);
            
            % Costruzione del vettore dei rami di valle di ogni ramo (0 = foce)
            [i_confluenze,j_confluenze]=find(matrice_confluenze);
            ramo_a_valle=zeros(n_rami,1);
            ramo_a_valle(j_confluenze)=i_confluenze;
            
            % Se non esistente, inizializza la mappa
            if nargin<3 || isempty(memo)
                memo=containers.Map('KeyType','uint32','ValueType','any');
            end
            
                        
            % Ciclo sui rami sorgente
            sequenze=cell(numel(rami_sorgente),1);
            for r=1:numel(rami_sorgente)
                
                ramo=rami_sorgente(r);
                
                % Se già esplorato, prende direttamente la sequenza già nota
                if isKey(memo,ramo)
                    sequenze{r}=memo(ramo);
                    continue;
                end
                
                % Vettore temporaneo per la sequenza corrente
                percorso=zeros(1,ceil(size(matrice_confluenze,1)/2)+1);  % lunghezza iniziale (si espande se necessario)
                i=1;
                percorso(i)=ramo;
                
                % Ricostruzione iterativa del percorso fino alla foce o fino a un ramo già esplorato
                while ramo_a_valle(percorso(i))~=0
                    
                    ramo_valle = ramo_a_valle(percorso(i));
                    
                    % Se il ramo a valle è già esplorato concatena i percorsi
                    if isKey(memo, ramo_valle)
                        percorso=[percorso(1:i),memo(ramo_valle)];
                        i=length(percorso);
                        break;
                    end
                    
                    % Estensione vettore temporaneo se necessario
                    i=i+1;
                    if i>numel(percorso)
                        percorso=[percorso,zeros(1,numel(percorso))]; %#ok<AGROW>
                    end
                    percorso(i)=ramo_valle;
                    
                end
                percorso=percorso(1:i);         % troncamento del percorso
                
                
                % Salvataggio dei sottopercorsi esplorati nella Mappa
                for j=1:numel(percorso)
                    ramo_j=percorso(j);
                    if ~isKey(memo,ramo_j)
                        memo(ramo_j)=uint32(percorso(j:end));
                    end
                end
                
                % Salva la sequenza corrente
                sequenze{r} = percorso;
                
            end
            
            
        end
        
        
        function ordine_Strahler=strahler(matrice_confluenze)
            
            % ordine_Strahler=strahler(matrice_confluenze)
            %
            % Calcola l'ordine di Strahler di tutto il reticolo.
            % INPUT
            %   matrice_confluenze = matrice sparsa numero_rami x numero_rami, matrice_confluenze(i,j)=1 se j confluisce in i
            % OUTPUT
            %   ordine_Strahler = vettore con l'ordine di Strahler di tutti i rami
            
            
            % Inizializzazione
            ordine_Strahler=NaN(size(matrice_confluenze,1),1);
            rami_correnti=find(sum(matrice_confluenze,2)==0);
            ordine_Strahler(rami_correnti)=1;
            cell_confluenze=num2cell(matrice_confluenze,2);
 
            % Ciclo sui rami
            while isempty(rami_correnti)==0
                
                % rami a valle dei rami correnti
                [rami_valle_rami_correnti,~]=find(matrice_confluenze(:,rami_correnti));
                
                % n-uple di rami confluenti nei rami a valle
                rami_monte_rami_valle=cellfun(@(x) find(x),cell_confluenze(rami_valle_rami_correnti),'UniformOutput',false);
                
                % Rami a monte
                ordine_Strahler_rami_monte=cellfun(@(x) ordine_Strahler(x), rami_monte_rami_valle,'UniformOutput',false);
                indici_rami_valle_validi=find(cellfun(@(x) all(isfinite(x)),ordine_Strahler_rami_monte ));
                ordine_Strahler_rami_monte=ordine_Strahler_rami_monte(indici_rami_valle_validi);
                
                % rami a valle e rami correnti ancora da assegnare
                rami_valle_non_aggiornabili=rami_valle_rami_correnti(setdiff(1:length(rami_valle_rami_correnti),indici_rami_valle_validi));
                rami_correnti_da_mantenere=rami_monte_rami_valle(ismember(rami_valle_rami_correnti,rami_valle_non_aggiornabili));
                rami_correnti_da_mantenere=(cellfun(@(x) x',rami_correnti_da_mantenere,'UniformOutput',false));
                rami_correnti_da_mantenere=unique(vertcat(rami_correnti_da_mantenere{:}));
                
                % Aggornamento ordine di Strahler
                massimi_Strahler_rami_da_aggiornare=cellfun( @(x) struct('massimo',max(x),'flag_aggiornamento',sum(x==max(x))>=2) ,ordine_Strahler_rami_monte);
                if isempty(massimi_Strahler_rami_da_aggiornare)==0
                    ordine_Strahler(rami_valle_rami_correnti(indici_rami_valle_validi([massimi_Strahler_rami_da_aggiornare.flag_aggiornamento])))=[massimi_Strahler_rami_da_aggiornare([massimi_Strahler_rami_da_aggiornare.flag_aggiornamento]).massimo]+1;
                    ordine_Strahler(rami_valle_rami_correnti(indici_rami_valle_validi([massimi_Strahler_rami_da_aggiornare.flag_aggiornamento]==0)))=[massimi_Strahler_rami_da_aggiornare([massimi_Strahler_rami_da_aggiornare.flag_aggiornamento]==0).massimo];
                end
                
                % rami da mantenere nell'esplorazione
                rami_correnti=[rami_correnti_da_mantenere;rami_valle_rami_correnti(indici_rami_valle_validi)];
                
            end
            
            
        end
        
        
        function coord_punti=polilinea2punti(coord,n_punti)
            
            % coord_punti=polilinea2punti(coord,n_punti)
            %
            % Estrae le coordinate di n_punti equidistanziati suluna polilinea.
            % INPUT:
            %   coord = matrice nx2 delle coordinate dei punti ordinati della polilinea
            %   n_punti = numero di punti equidistanziati da estrarre dalla polilinea
            % OUTPUT:
            %   coord_punti = matrice nx2 delle coordinate dei punti equidistanziati estratti dalla polilinea
            
            
            % Controllo input
            if size(coord,1)==1
                coord_punti=ones(n_punti,1)*coord;
                return
            end
            
            
            [L,Lcum]=RiverNetwork.lunghezzaPolilinea(coord);    % lunghezza e lunghezze parziali della polilinea
            ds=L/n_punti;
            ss=ds/2:ds:L-ds/2;                                  % coordinata curvilinea dei punti
            coord_punti=[interp1(Lcum,coord(:,1),ss)',interp1(Lcum,coord(:,2),ss)'];
            
        end
        
        
        function aree_drenate=areeDrenate(pnt,aree_monte,sezioni,P,flag_areecomp)            

            % aree_drenate=areeDrenate(pnt,aree_monte,sezioni,P,flag_areecomp)
            %
            % Ricostruisce le aree drentate da ogni sezione a partire dal raster delle aree cumulate e dei puntatori idrologici.
            %
            % INPUT:
            %   pnt = mappa dei puntatori idrologici
            %   aree_monte = mappa delle aree drenate
            %   sezioni = matrice n x 2 con le coordinate matrice delle sezioni
            %   P = codici dei puntatori idrologici (OPZIONALE)
            %   flag_areecomp = 1: attiva il calcolo delle aree di competenza (OPZIONALE, se non specificato = 0) 
            % OUTPUT:
            %   aree_drenate = cell array in ogni elemento del quale c'e' un vettore degli indici assoluti delle celle
            %                  appartenenti alla data area di competenza
            
            
            
            if nargin==3
                P=RiverNetwork.PUNTATORI;
                flag_areecomp=0;
            elseif nargin==4
                flag_areecomp=0;
            end
            
            % eliminazione dati mancanti
            pnt(pnt<0)=NaN;
            aree_monte(aree_monte<0)=NaN;
            [n,m]=size(pnt);
            [n_orig,m_orig]=size(pnt);
            
            
            % matrici ausiliarie
            M=NaN(n+2,m+2);
            M(2:end-1,2:end-1)=pnt;
            pnt=M;
            [n,m]=size(pnt);
            di=ones(3,1)*[-1 0 1];
            dj=[-1;0;1]*ones(1,3);
            di=di(:); %#ok<NASGU>
            dj=dj(:); %#ok<NASGU>
            P=P(end:-1:1,end:-1:1);
            dd=P(:);
            iD=[-n-1 -n -n+1 -1 0 1 n-1 n n+1]';
            ND=length(iD);
            
            
            % ordinamento sezioni per area cumulata crescente
            I_sezioni=sub2ind([n_orig,m_orig],sezioni(:,1),sezioni(:,2));
            aree_monte_sezioni=aree_monte(I_sezioni);
            [aree_monte_sezioni_sort,indici_sort]=sort(aree_monte_sezioni);
            sezioni_orig=sezioni;
            sezioni=sezioni_orig(indici_sort,:);
            [indici_ordinati,indici_resort]=sort(indici_sort); %#ok<ASGLU> % indici per riordinare le aree secondo l'ordine originale delle sezioni
            
            
            
            % RICOSTRUZIONE AREE DRENATE
            
            % nuove coordinate delle sezioni sulla matrice ingrandita (originale+cornice)
            N=size(sezioni,1);
            elenco_sezioni=zeros(1,N);
            for i=1:N
                elenco_sezioni(i)=sub2ind([n,m],sezioni(i,1)+1,sezioni(i,2)+1);
            end
            
            % Ciclo Principale
            aree_drenate=cell(1,length(elenco_sezioni));
            h=waitbar(0);
            for s=1:length(elenco_sezioni)
                
                % sezione s
                p=elenco_sezioni(s);
                area_TOT=NaN(1,aree_monte_sezioni_sort(s)); k_area=1;
                area_TOT(k_area)=p;
                punti_da_esam=p;
                
                % ciclo sui punti da controllare
                k=0;
                while isempty(punti_da_esam)==0
                    
                    k=k+1;
                    
                    % celle delle 8 che circondano le celle da esaminare che puntano verso di esse
                    punti_nuovi=[];
                    i_punti_intorno=ones(ND,1)*punti_da_esam+iD*ones(1,length(punti_da_esam));
                    punti_nuovi=unique([punti_nuovi,(i_punti_intorno((pnt(i_punti_intorno)-dd*ones(1,length(punti_da_esam)))==0))']);
                    
                    % controllo sulla presenza di sezioni gia' processate
                    [sezioni_processate,indici_sezioni_processate]=intersect(elenco_sezioni(1:s-1),punti_nuovi);
                    area_processata_tot=[];
                    if isempty(sezioni_processate)==0
                        
                        L_aree=cellfun(@length,aree_drenate(indici_sezioni_processate));
                        k_area_proc=0;
                        area_processata_tot=NaN(1,sum(L_aree));
                        
                        for sp=1:length(sezioni_processate)
                            
                            area_processata_tot(k_area_proc+1:k_area_proc+L_aree(sp))=aree_drenate{indici_sezioni_processate(sp)};
                            k_area_proc=k_area_proc+L_aree(sp);
                            
                        end
                        
                        if flag_areecomp==0
                           
                            area_TOT(k_area+1:k_area+length(area_processata_tot))=area_processata_tot;
                            k_area=k_area+length(area_processata_tot);
                            
                        end
                        
                        
                    end
                    
                    % celle da aggiungere all'area
                    punti_nuovi=setdiff(unique([punti_nuovi,setdiff(punti_nuovi,area_TOT(1:k_area))]),area_processata_tot);
                    try
                        area_parz=unique([area_TOT(1:k_area),punti_nuovi]);
                    catch
                        keyboard
                    end
                    k_area=length(area_parz);
                    area_TOT(1:k_area)=area_parz;
                    punti_da_esam=punti_nuovi;
                    
                    
                end
                area_TOT=area_TOT(1:k_area);
                aree_drenate{s}=area_TOT;
                
                
                waitbar(s/length(elenco_sezioni),h);
            end
            
            
            % conversione delle coordinate sulla griglia originale
            for s=1:length(elenco_sezioni)
                area=aree_drenate{s};
                [i_area,j_area]=ind2sub([n,m],area);
                i_area=i_area-1;
                j_area=j_area-1;
                i_area=(n-2)-i_area+1;
                area=sub2ind([n-2,m-2],n_orig-i_area+1,j_area);
                %     save(nome_file_area_processata,'area_processata');
                aree_drenate{s}=area;
            end
            
            close(h);
            
            % riordinamento delle aree
            aree_drenate=aree_drenate(indici_resort);
            
        end
        
        
        function topologia_raster=topologia_reticolo(ret,pnt,aree_monte,P)
            
            % topologia_raster=topologia_reticolo(ret,pnt,aree_monte,P)
            %
            % Ricostruisce rami e topologia di un dominio idrologico a partire dalle idroderivate.
            % INPUT:
            %   ret = mappa del reticolo (1 = cella di reticolo, 0 fuori dal reticolo)
            %   pnt = mappa dei puntatori idrologici del reticolo (0 fuori dal dominio)
            %   aree_monte = mappa delle aree drenate (0 fuori dal dominio)
            %   P = matrice 3x3 dei codici dei puntatori idrologici (OPZIONALE)
            % OUTPUT:
            %   topologia_raster = struct con i seguenti campi:
            %                    indici_rami: cell array con gli indici matrice dei rami {913×1 cell}
            %                    indici_nodi: vettore con gli indici matrice dei nodi (from-node o to-node di tutti i rami)
            %                    indici_foci: vettore con gli indici matrice delle foci
            %                    indici_sorgenti: vettore con gli indici matrice delle sorgenti
            %                    indici_confluenze: vettore con gli indici matrice delle confluenze (to-node comunidi più rami)
            %                    from_node: vettore con gli indici matrice dei from-node dei rami (stesso ordinamento di indici_rami)
            %                    to_node: vettore con gli indici matrice dei to-node dei rami (stesso ordinamento di indici_rami)
            %                    indici_rami_foci: cell array, nell'elemento i ci sono gli indici dei rami che hanno come to-node
            %                                      la foce i (stesso ordinamento di indici_foci)
            %                    indici_rami_testata: vettore con gli indici dei rami che hanno come from-node le sorgenti
            %                                         (stesso ordinamento di indici_sorgenti)
            %                    indici_finali_rami: vettore con gli indici matrice della cella più a monte di ogni ramo
            %                    aree_monte_rami: vettore con le aree drenate (area drenata della cella più a monte) di ogni ramo [km2]
            %                    rami_bacini: cell array, l'elemento i contiene i rami del bacino i-esimo, ordinati per
            %                                 area drenata crescente (i bacini sono a loro volta ordinati per area crescente)
            %                    matrice_confluenze = matrice sparsa numero_rami x numero_rami, matrice_confluenze(i,j)=1 se j confluisce in i
            %                                        (es: riga i-esima [0 0 1 0 0 0 1 1]: i rami 3, 7 e 8 confluiscono nel rami i)
            
            
            
            % Controllo raster
            ret(ret<0 | isnan(ret))=0;
            pnt(pnt<0 | isnan(pnt))=0;
            aree_monte(aree_monte<0 | isnan(aree_monte))=0;
            try
                pnt(ret==1 & pnt==0)=5;   % reticolo privo di puntatori -> pit
            catch
                keyboard
            end
            
            
            % Codici puntatori di default
            if nargin==3
                [~,P]=obj.puntatori2direzioni;
            end
            
            
            % Puntatori idrologici e direzioni
            Pinv=rot90(P',2)';  % puntatori inversi
            direzioni=RiverNetwork.puntatori2direzioni(P);
            
            
            % Indici matrice del reticolo
            indici_reticolo=find(ret==1);
            [i_ret,j_ret]=ind2sub(size(ret),indici_reticolo);
            
            
            % Celle di valle di ogni cella di reticolo
            celle_valle=sub2ind(size(ret),i_ret+direzioni(pnt(indici_reticolo),1),j_ret+direzioni(pnt(indici_reticolo),2));
            
            
            % Sorgenti
            Pinv_unroll=NaN(9,1);
            for i=1:9
                Pinv_unroll(i)=Pinv(P==i);
            end
            vicini=NaN(length(indici_reticolo),9);  % celle che circondano ogni cella di reticolo
            for i=1:9
                vicini(:,i)=sub2ind(size(ret),i_ret+direzioni(i,1),j_ret+direzioni(i,2));
            end
            % valori dei puntatori e del reticolo delle celle che circondano ogni cella di reticolo
            valori_puntatori=pnt(vicini);
            valori_reticolo=ret(vicini)+1;                                      % matrice con 1 = versante, 2 = reticolo
            Pinv_UNROLL=ones(size(vicini,1),1)*Pinv_unroll';
            reticolo_converg=valori_reticolo.*((valori_puntatori-Pinv_UNROLL)==0);
            reticolo_converg(reticolo_converg==0)=NaN;                          % diverso da zero solo nelle celle che convergono nella cella di reticolo
            indici_sorgenti=indici_reticolo((all(reticolo_converg~=2,2)) | reticolo_converg(:,5)==2 & sum(isfinite(reticolo_converg),2)==1 | all(([valori_reticolo(:,1:4),valori_reticolo(:,6:9)]==1),2));  % celle le cui celle convergenti NON sono di reticolo (possono essere di versante o assenti) oppure sono pit isolati oppure sono celle di reticolo isolate
            
                        
            % Foci
            indici_foci=setdiff(celle_valle,indici_reticolo);
            ii=find(ismember(celle_valle,indici_foci));
            indici_foci=unique([indici_reticolo(ii(:));find(ret==1 & pnt==5)]);
            aree_foci=aree_monte(indici_foci);
            [~,indici_sort]=sort(aree_foci);
            indici_foci=indici_foci(indici_sort);
            
            
            % Confluenze
            reticolo_converg(reticolo_converg==1)=NaN;
            indici_confluenze=indici_reticolo(sum(reticolo_converg==2,2)>1);  % celle in cui ci sono almeno 2 celle convergenti (possono essere anche foci)
            
            
            % Rami
            indici_nodi=intersect(unique([indici_foci;indici_sorgenti;indici_confluenze]),indici_reticolo);
            % from_node e to_node potenziali (tutti i nodi)
            from_node_pot=indici_nodi;
            to_node_pot=indici_nodi;
            from_node_pot_controllo=from_node_pot;      % sezioni "di controllo": penultima cella verso valle di ogni ramo (l'ultima è quasi sempre una confluenza)
            % ricostruzione dei rami
            indici_rami=cell(length(from_node_pot),1);  % indici matrice delle celle di ogni ramo
            [from_node,to_node]=deal(NaN(length(indici_rami),1));
            i_rami_da_elim=[];
            n_punti_inizializzazione=10*ceil(length(indici_reticolo)/length(indici_nodi));
            while isempty(from_node_pot_controllo)==0
                for i=1:length(from_node_pot)
                    indici_ramo=RiverNetwork.percorsoReticolo(pnt,ret,from_node_pot(i),to_node_pot,n_punti_inizializzazione);    % ricostruisce i percorsi da ogni nodo al primo nodo verso valle (= rami)
                    indici_rami{i}=indici_ramo;
                    from_node_pot_controllo=setdiff(from_node_pot_controllo,from_node_pot(i));
                    % ramo corrente
                    if isempty(indici_ramo)==0
                        from_node(i)=indici_ramo(1);    % assegnazione del from_node
                        to_node(i)=indici_ramo(end);    % assegnazione del to_node
                    else
                        i_rami_da_elim=[i_rami_da_elim,i]; %#ok<AGROW>
                    end
                end
            end
            indici_rami(i_rami_da_elim)=[];
            from_node(i_rami_da_elim)=[];
            to_node(i_rami_da_elim)=[];
            
            
            % Matrice confluenze temporanea (prima dell'eleiminazione dei rami anomali)
            nrami=length(indici_rami);
            [indici_i,indici_j]=deal(NaN(nrami*2,1));
            k=0;
            for r=1:nrami
                rami_monte=find(to_node==from_node(r));
                if isempty(rami_monte)==0
                    indici_i(k+1:k+length(rami_monte))=r;
                    indici_j(k+1:k+length(rami_monte))=rami_monte(:);
                    k=k+length(rami_monte);
                end
            end
            indici_i=indici_i(1:k);
            indici_j=indici_j(1:k);
            matrice_confluenze=sparse(indici_i,indici_j,ones(size(indici_i)),nrami,nrami);  % l'elemento (i,j) è non nullo se il ramo j confluisce nel ramo i
            
            
            % Rami di una sola cella
            Lrami=cellfun(@length,indici_rami);
            indici_rami_1cella=find(Lrami==1);
            
            
            % Rami foce di una cella con un solo ramo a monte
            i_rami_da_elim=[];
            for ir=1:length(indici_rami_1cella)
                r=indici_rami_1cella(ir);
                rami_monte=setdiff(find(matrice_confluenze(r,:)),r);
                if length(rami_monte)==1
                    i_rami_da_elim=[i_rami_da_elim,r]; %#ok<AGROW>
                end
            end
            indici_rami(i_rami_da_elim)=[];
            from_node(i_rami_da_elim)=[];
            to_node(i_rami_da_elim)=[];
            
            
            % area a monte dei rami
            indici_finali_rami=NaN(length(indici_rami),1);
            for i=1:length(indici_rami)
                if length(indici_rami{i})>1 && sum(ismember(indici_foci,indici_rami{i}(end)))==0  % ramo formato da più celle e NON di foce
                    indici_finali_rami(i)=indici_rami{i}(end-1);
                elseif length(indici_rami{i})==1
                    indici_finali_rami(i)=indici_rami{i}(end);
                elseif length(indici_rami{i})>1
                    indici_finali_rami(i)=indici_rami{i}(end-1);
                end
            end
            aree_monte_rami=aree_monte(indici_finali_rami);
            
            
            % riordinamento rami per area drenata crescente
            [aree_monte_rami,indici_sort]=sort(aree_monte_rami);
            from_node=from_node(indici_sort);
            to_node=to_node(indici_sort);
            indici_rami=indici_rami(indici_sort);
            indici_finali_rami=indici_finali_rami(indici_sort);
            
                        
            % Rami sorgente
            [nodi_comuni,indici_rami_testata]=intersect(from_node,indici_sorgenti); %#ok<ASGLU>
            
            
            % Rami foce
            indici_rami_foci=cell(length(indici_foci),1);
            for i=1:length(indici_foci)
                indici_rami_foci{i}=find(to_node==indici_foci(i));
            end
            
            
            % Matrice confluenze
            nrami=length(indici_rami);
            [indici_i,indici_j]=deal(NaN(nrami*2,1));
            k=0;
            for r=1:nrami
                rami_monte=find(to_node==from_node(r));
                if isempty(rami_monte)==0
                    indici_i(k+1:k+length(rami_monte))=r;
                    indici_j(k+1:k+length(rami_monte))=rami_monte(:);
                    k=k+length(rami_monte);
                end
            end
            indici_i=indici_i(1:k);
            indici_j=indici_j(1:k);
            indici_diagonali=find(indici_i==indici_j);  % elimina rami che confluiscono in sè stessi (rami di 1 pixel)
            indici_i(indici_diagonali)=[];
            indici_j(indici_diagonali)=[];
            matrice_confluenze=sparse(indici_i,indici_j,ones(size(indici_i)),nrami,nrami);  % l'elemento (i,j) è non nullo se il ramo j confluisce nel ramo i
            
            
            % Bacini massimali
            rami_bacini=cell(length(indici_foci),1);
            for f=1:length(indici_foci)
                rami_valle=indici_rami_foci{f}(:)';   % rami che confluiscono nella foce
                rami_bacino=[];
                for g=1:length(rami_valle)
                    rami_bacino_parz=RiverNetwork.RamiBaciniMonte(rami_valle(g),matrice_confluenze);
                    rami_bacino=[rami_bacino,rami_bacino_parz{1}]; %#ok<AGROW>
                end
                rami_bacini{f}=unique(rami_bacino);
            end
            
            
            % Risultati
            topologia_raster.indici_rami=indici_rami;
            topologia_raster.indici_nodi=indici_nodi;
            topologia_raster.indici_foci=indici_foci;
            topologia_raster.indici_sorgenti=indici_sorgenti;
            topologia_raster.indici_confluenze=indici_confluenze;
            topologia_raster.from_node=from_node;
            topologia_raster.to_node=to_node;
            topologia_raster.indici_rami_foci=indici_rami_foci;
            topologia_raster.indici_rami_testata=indici_rami_testata;
            topologia_raster.indici_finali_rami=indici_finali_rami;
            topologia_raster.aree_monte_rami=aree_monte_rami;
            topologia_raster.rami_bacini=rami_bacini;
            topologia_raster.matrice_confluenze=matrice_confluenze;
            
            
        end
                
        
        function writeShape(nome_file,coordinate_polilinee,tabella_campi)
            
            % writeShape(nome_file,coordinate_polilinee,tabella_campi)
            % 
            % Scrive uno shape di polilinee con assegnata tabella di attributi.
            % INPUT
            %   nome_file = nome file shape da scrivere
            %   coordinate_polilinee = matrice n x 2 con le coordinate delle polilinee separate da ricghe NaN
            %   tabella_campi = cell array con attributi per ogni polilinea (la prima riga contiene i nomi dei campi)
            
            
            % Costruzione della geo-struttura
            coord_rami_x=coordinate_polilinee(:,1); %#ok<NASGU>
            coord_rami_y=coordinate_polilinee(:,2); %#ok<NASGU>
            stringa_geo_struttura='geo_struttura=struct(''Geometry'',''Line'',''X'',coord_rami_x,''Y'',coord_rami_y,';
            % cistruzione della tabella degli attributi nella geo-struttura
            for c=1:size(tabella_campi,2)
                stringa_geo_struttura=[stringa_geo_struttura,'''',tabella_campi{1,c},''',tabella_campi(2:end,',num2str(c),'),']; %#ok<AGROW>
            end
            stringa_geo_struttura=[stringa_geo_struttura(1:end-1),');'];
            eval(stringa_geo_struttura);
            
            % scrittura dello shapefile
            shapewrite(geo_struttura,nome_file);
            
        end
        
        
        function Distanze=DifferenzeCoordinateReticoli(coord1,coord2)
            
            % Distanze=DifferenzeCoordinateReticoli(coord1,coord2)
            %
            % Calcola tutte le possibili differenze tra i punti corrispondenti di due set di polilinee ognuna avente le coordinate 
            % su numero_punti punti.
            % INPUT
            %   coord1 = matrice 3D con le coordinate di n polilinee (numero_punti x 2 x n)
            %   coord2 = matrice 3D con le coordinate di m polilinee (numero_punti x 2 x m)
            % OUTPUT
            %   Distanze = matrice 3D con tutte le possibili distanze (n x m x numero_punti)
            
            N1=size(coord1,3); N2=size(coord2,3);
            Distanze=single(NaN(N1,N2,RiverNetwork.n_punti_interpolazione));
            for p=1:RiverNetwork.n_punti_interpolazione
                x1=squeeze(coord1(p,1,:));
                x2=squeeze(coord2(p,1,:));
                y1=squeeze(coord1(p,2,:));
                y2=squeeze(coord2(p,2,:));
                Distanze(:,:,p)=sqrt((x1(:)*single(ones(N2,1))-single(ones(N1,1))*x2(:)').^2+(y1(:)*single(ones(N2,1))-single(ones(N1,1))*y2(:)').^2);
            end
            
        end
        
        
        function d=geoDistanzeKm(lon1,lat1,lon2,lat2)
            
            % d=geoDistanzeKm(lon1,lat1,lon2,lat2)
            %
            % Calcola la distanza in km lungo una geodetica tra uno o più punti di
            % coordinate (lon1,lat1) e (lon2,lat2).
            % INPUT
            %   lon1 = longitudini del primo set di punti
            %   lat1 = latitudini del primo set di punti
            %   lon2 = longitudini del secondo set di punti
            %   lat2 = latitudini del secondo set di punti
            % OUPTUT
            %   d = matrice di tutte le possibili distanze (n_punti1 x n_punti2)
            
            
            % Controllo input
            if length(lon1)~=length(lat1) || length(lon2)~=length(lat2)
                d=[];
                disp('ERRORE: dimensioni di longitudine e latitudine non coerenti');
                return
            end
            
            R=6371; % raggio terrestre [km]
            n1=length(lon1);
            n2=length(lon2);
            a=sin(deg2rad((ones(n1,1)*lat2(:)'-lat1(:)*ones(1,n2))/2)).^2+cos(deg2rad(lat1(:)*ones(1,n2))).*cos(deg2rad(ones(n1,1)*lat2(:)')).*sin(deg2rad((ones(n1,1)*lon2(:)'-lon1(:)*ones(1,n2))/2)).^2;
            d=R*2*atan2(sqrt(a),sqrt(1-a));
            
        end
        
        
        function punti_centrali_rami=getPuntiCentriRami(coord)
            
            % punti_centrali_rami=getPuntiCentriRami(coord)
            %
            % Calcola le coordinate dei punti centrali di ogni ramo
            % INPUT
            %   coord = cell array con le coordinate dei rami
            % OUPUT
            %   punti_centrali_rami = coordinate dei punti centrali
            
            
            % Calcola il punto a metà della lunghezza di ogni ramo
            npunti_rami=cellfun(@length,coord);
            punti_centrali_rami=NaN(length(coord),2);
            for r=1:length(coord)
                punti_centrali_rami(r,:)=(coord{r}(floor(npunti_rami(r)/2),:)+coord{r}(ceil(npunti_rami(r)/2),:))/2;
            end
            
        end
        
        
        function distanze_punti=DistanzePunti(coord1,coord2)
            
            % Distanze=DistanzePunti(coord1,coord2)
            %
            % Calcola tutte le possibili distanze tra due insiemei di punti
            % INPUT
            %   coord1 = matrice delle coordinate del primo set di punti
            %   coord2 = matrice delle coordinate del secondo set di punti
            % OUTPUT
            %   distanze_punti = matrie di tutte le possibili distanze
            
            n1=size(coord1,1); n2=size(coord2,1);
            distanze_punti=sqrt((coord1(:,1)*ones(1,n2)-ones(n1,1)*coord2(:,1)').^2+(coord1(:,2)*ones(1,n2)-ones(n1,1)*coord2(:,2)').^2);
            
        end
        
        
        function differenze=DifferenzeVettori(x1,x2)
            
            % Differenze=DifferenzeAree(x1,x2)
            %
            % Calcola tutte le possibili differenze tra due vettori.
            % INPUT
            %   x1 = primo vettore
            %   x2 = secondo vettore
            % OUTPUT
            %   differenze = matrice lunghezza_vettore1 x lunghezza_vettore2 con tutte le possibili differenze
            
            n1=length(x1); n2=length(x2);
            differenze=(ones(n1,1)*(x2(:)')-x1(:)*ones(1,n2));
            
        end
        
        
        function rami_sottobacini=RamiBaciniMonte(rami,matrice_confluenze)
            
            % rami_sottobacini=RamiBaciniMonte(rami,matrice_confluenze)
            % 
            % Ricostruisce tutti i rami a monte di un dato ramo.
            % INPUT
            %   rami = rami di partenza
            %   matrice_confluenze = matrice sparsa numero_rami x numero_rami, matrice_confluenze(i,j)=1 se j confluisce in i
            % OUTPUT
            %   rami_sottobacini = cell array con i rami a monte di ciascun ramo di input
            
            rami_sottobacini=cell(length(rami),1);
            for r=1:length(rami)
                rami_sottobacini{r}=RiverNetwork.ramiMonte(matrice_confluenze,rami(r));
            end
            
        end
        
        
        function rami_monte=ramiMonte(matrice_confluenze,ramo_valle)
            
            % rami_monte=ramiMonte(matrice_confluenze,ramo_valle)
            %
            % Ricostruisce quali sono i rami appartenenti al bacino a monte di una dato ramo.
            % INPUT
            %   matrice_confluenze = matrice delle confluenze, l'elemento (i,j), vale 1 se il ramo j confluisce nel ramo i
            %   ramo_valle = ramo di chiusura del bacino di interesse
            % OUTPUT
            %   rami_monte = elenco dei rami a monte del ramo in input
            
            
            % Inizializzazione
            rami_monte_corrente=find(matrice_confluenze(ramo_valle,:));
            rami_monte=[ramo_valle,rami_monte_corrente];
            
            % Ciclo di esplorazione verso monte
            while isempty(rami_monte_corrente)==0
                areecomp_monte_attuale=[];
                for i=1:length(rami_monte_corrente)
                    areecomp_monte_attuale=[areecomp_monte_attuale,find(matrice_confluenze(rami_monte_corrente(i),:))]; %#ok<AGROW>
                end
                rami_monte_corrente=areecomp_monte_attuale;
                rami_monte=[rami_monte,rami_monte_corrente]; %#ok<AGROW>
            end
            rami_monte=unique(rami_monte);
            
        end
        
        
        function modulazione=ExpModulation(x_min,x_max,y_min,y_max,k,valori)
            
            % modulazione=ExpModulation(x_min,x_max,y_min,y_max,k,valori)
            %
            % Esponenziale decrescente riscalato in modo che arrivi da y_max a y_min nel range [x_min,x_max], calcolata su valori.
            % fattore k nell'esponente
            % INPUT
            %   x_min = valore minimo dell'intervallo su cui viene calcolato l'esponenziale
            %   x_max = valore massimo dell'intervallo su cui viene calcolato l'esponenziale
            %   y_min = valore minimo dell'esponenziale
            %   y_max = valore massimo dell'esponenziale
            %   k = fattore di riscalatura dell'esponenziale
            %   valori = valori di x su cui viene calcolato l'esponenziale
            % OUTPUT
            %   modulazione = esponenziale riscalato calcolato su valori
            
            temp=(y_max-y_min)*exp(k/(x_max-x_min)*(x_min-valori));
            modulazione=max(y_min,min(y_max,y_min+(temp-min(temp))*(y_max-y_min)/(max(temp)-min(temp))));
            
        end
        
        
        function [distanza,std_distanze]=distanzaPolilinee(coord1,coord2,n_punti_confronto)
            
            % [distanza,std_distanze]=distanza_polilinee(coord1,coord2,n_punti_confronto)
            %
            % Calcola una distanza tra due polilinee usando n punti equidistanziati su ciascuna di esse.
            % INPUT
            %   coord1 = matrice n x 2 con le coordinate dei punti della polilinea 1
            %   coord2 = matrice n x 2 con le coordinate dei punti della polilinea 2
            %   n_punti_confronto = numero di punti equidistanziati sulle polilinee sui quali viene calcolata la distanza (DEFAULT: 10)
            % OUPUT
            %   distanza = distanza tra le polilinee in unità di misura delle coordinate
            %   std_distanze = deviazione standard delle distanze tra i singoli punti
            
            
            % Controllo input
            if nargin==2
                n_punti_confronto=10;
            end
            
            
            % Calcolo coordinate punti equidistanziati su entrambe le polilinee
            punti1=punti_polilinea(coord1,n_punti_confronto);
            punti2=punti_polilinea(coord2,n_punti_confronto);
            
            % calcolo distanza
            distanze_punti=sqrt((punti1(:,1)-punti2(:,1)).^2+(punti1(:,2)-punti2(:,2)).^2);
            std_distanze=std(distanze_punti);
            distanza=mean(distanze_punti);
            
        end
        
        
        function [tabella_corrispondenze,J]=corrispondenzePolilineeNpuntiAree(coord_polilinee1, coord_polilinee2, aree_polilinee1, aree_polilinee2, peso_distanze, peso_aree, flag_distanze)
                        
            % [tabella_corrispondenze,J]=corrispondenzePolilineeNpuntiAree(coord_polilinee1, coord_polilinee2, aree_polilinee1, aree_polilinee2, peso_distanze, peso_aree, flag_distanze)
            %
            % Calcolo tabella corrispondenze e funzionale di costo per tutte le coppie di polilinee tra il primo e il secondo insieme.
            %
            % INPUT
            %   coord_polilinee1 = matrice 3D con le coordinate delle polinee del primo insieme (n_punti x n_polilinee x 2)
            %   coord_polilinee2 = matrice 3D con le coordinate delle polinee del secondo insieme (n_punti x n_polilinee x 2)
            %   area_polilinea1 = aree associate alle polilinee del primo insieme
            %   aree_polilinee2 = aree associate alle polilinee del secondo insieme
            %   peso_aree = peso delle aree nella funzione di costo
            %   peso_distanze = peso delle distanze nalla funzione di costo
            %   flag_distanze = 1: LRMSE, 2: Fréchet
            % OUTPUT
            %   tabella_corrispondenze = tabella corripondenze delle coppie più vicine di polilinee tra il primo e il secondo insieme
            %   J = valori del funzionale di costo
            
                        
            % Controllo input
            if nargin==6
                flag_distanze=1;
            end
            
            % numeri di polilinee
            n_polilinee1=length(aree_polilinee1);
            n_polilinee2=length(aree_polilinee2);
            n_punti=size(coord_polilinee1,1);
            
            % costo distanza aree drenate dalle aste
            errori_aree_adim=(aree_polilinee2(:)*ones(1,n_polilinee1)-ones(n_polilinee2,1)*aree_polilinee1)./(ones(n_polilinee2,1)*aree_polilinee1);
            
            % distanze tra polilinee
            L_polilinee1=NaN(1,n_polilinee1);
            for i=1:n_polilinee1
                L_polilinee1(i)=RiverNetwork.lunghezzaPolilinea(squeeze(coord_polilinee1(:,i,:)));
            end
            if any(L_polilinee1>0)
                L_polilinee1(L_polilinee1==0)=mean(L_polilinee1(L_polilinee1>0));
            else
                L_polilinee1(L_polilinee1==0)=1;
            end
            if n_polilinee1>1 && n_polilinee2>1
                
                if flag_distanze==1         % LRMSE
                    errori_distanze_adim=squeeze(mean( ( repmat(squeeze(coord_polilinee2(:,:,1)),1,1,n_polilinee1) - repmat( reshape(squeeze( coord_polilinee1(:,:,1) ), [n_punti,1,n_polilinee1]  ),1,n_polilinee2,1) ).^2 + ...
                        ( repmat(squeeze(coord_polilinee2(:,:,2)),1,1,n_polilinee1) - repmat( reshape(squeeze( coord_polilinee1(:,:,2) ), [n_punti,1,n_polilinee1]  ),1,n_polilinee2,1) ).^2  ,1) ) ./  (ones(n_polilinee2,1)*L_polilinee1);
                else                        % Fréchet
                    for p=1:size(coord_polilinee1,2)
                        if size(unique(squeeze(coord_polilinee1(:,p,:)),'rows'),1)==1
                            errori_distanze_adim=squeeze(max( ( repmat(squeeze(coord_polilinee2(:,:,1)),1,1,1) - repmat( reshape(squeeze( coord_polilinee1(:,p,1) ), [n_punti,1,1]  ),1,n_polilinee2,1) ).^2 + ...
                                ( repmat(squeeze(coord_polilinee2(:,:,2)),1,1,1) - repmat( reshape(squeeze( coord_polilinee1(:,p,2) ), [n_punti,1,1]  ),1,n_polilinee2,1) ).^2  ,[],1) )' ./  (ones(n_polilinee2,1)*L_polilinee1(p));
                        else
                            dL=mode(sqrt(sum(diff(squeeze(coord_polilinee1(:,p,:))).^2,2)));
                            coordinate_curvilinee_aste_idrologiche=[zeros(1,size(coord_polilinee2,2));cumsum(sqrt(sum(diff(coord_polilinee2,1).^2,3)),1)];
                            L_polilinee2=coordinate_curvilinee_aste_idrologiche(end,:);
                            for p2=1:size(coord_polilinee2,2)
                                coord_polilinee2_dL=[interp1(coordinate_curvilinee_aste_idrologiche(:,p2),coord_polilinee2(:,p2,1),0:dL:L_polilinee2(p2))',...
                                    interp1(coordinate_curvilinee_aste_idrologiche(:,p2),coord_polilinee2(:,p2,2),0:dL:L_polilinee2(p2))']; %#ok<NASGU>
                            end
                            % -> calcolo della distanza di Fréchet considerando le diverse lunghezze delle polilinee
                        end
                    end
                end
                
            else
                
                % distanza per punti corrispondenti
                errori_distanze_adim=squeeze(mean( ( ( repmat(squeeze(coord_polilinee2(:,:,1)),1,1,n_polilinee1) - repmat( reshape(squeeze( coord_polilinee1(:,:,1) ), [n_punti,1,n_polilinee1]  ),1,n_polilinee2,1) ).^2 + ...
                    ( repmat(squeeze(coord_polilinee2(:,:,2)),1,1,n_polilinee1) - repmat( reshape(squeeze( coord_polilinee1(:,:,2) ), [n_punti,1,n_polilinee1]  ),1,n_polilinee2,1) ).^2 ) ,1) )' ./  (ones(n_polilinee2,1)*L_polilinee1);
                                
            end
            
            % funzione di costo
            J=peso_aree*abs(errori_aree_adim)+peso_distanze*abs(errori_distanze_adim);
            
            % Corrispondenze polilinee
            [~,indici_minimi]=min(J,[],1);
            tabella_corrispondenze=[(1:n_polilinee1)',indici_minimi'];
            
            
        end
        
        
        function coord_tratti=trattiConnessionePolilinee(coord_polilinee1, coord_polilinee2)
            
            % coord_tratti=trattiConnessionePolilinee(coord_polilinee1, coord_polilinee2)
            %
            % Genera le coordinate dei tratti (gruppi di segmenti) che connettono coppie di polilinee.
            % INPUT
            %   coord_polilinee1 = matrice 3D con le coordinate del primo insieme di polilinee (numero_polilinee x numero_punti x 2)
            %   coord_polilinee2 = matrice 3D con le coordinate del secondo insieme di polilinee (numero_polilinee x numero_punti x 2)
            % OUTPUT
            %   coord_tratti = matrice 3D con le coordinate dei tratti di connessione primo insieme di polilinee (numero_polilinee x numero_punti x 2)
                       
            
            [n,N,~]=size(coord_polilinee1);
            coord_tratti=NaN(n*3,2,N);
            idx1=1:3:n*3;
            idx2=2:3:n*3;
            coord_tratti(idx1,:,:)=permute(coord_polilinee1,[1 3 2]);
            coord_tratti(idx2,:,:)=permute(coord_polilinee2,[1 3 2]);
            
        end
        
                
        function [L,Lcum]=lunghezzaPolilinea(coord)
            
            % [L,Lcum]=lunghezzaPolilinea(coord)
            %
            % Calcola la lunghezza di una polilinea in base alle coordinate dei punti.
            % INPUT
            %   coord = matrice n x 2 con le coordinate dei punti
            % OUTPUT
            %   L = lunghezza della polilinea
            %   Lcum = lunghezza cumulata (coordinata curvilinea per ogni punto)
            
            
            differenze=diff(coord);
            coord(differenze(:,1)==0 & differenze(:,2)==0,:)=[];    % eliminazione di punti ripetuti
            Lcum=[0;cumsum(sqrt(sum(diff(coord,1,1).^2,2)))];       % coordinata curvilinea per ogni punto
            L=Lcum(end);                                            % lunghezza polilinea
            
        end
        
        
        function coord2=rototraslazionePolilinee(coord1,vettore_distanza,angolo,polo)
            
            % coord2=rototraslazionePolilinee(coord1,vettore_distanza,angolo,polo)
            %
            % Roto-trasla una polilinea in base a vettore traslazione, angolo e polo di rotazione.
            % INPUT
            %   coord1 = matrice nx2 con le coordinate dei punti ordinati della polilinea, 
            %            oppure cell array contenente in ogni elemento le coordinate di diverse polilinee
            %   vettore_distanza = vettore 1x2 con [dx,dy] per la traslazione
            %   angolo = angolo di rotazione nel piano [rad]
            %   polo = vettore 1x2 con le coordinate del polo di rotazione
            % OUTPUT
            %   coord2 = matrice nx2 con le coordinate di punti ordinati della polilinea roto-traslata,
            %            oppure cell array contenente in ogni elemento le coordinate delle polilinee roto-traslate
            
            
            % Controllo input
            if nargin==3
                polo=[0 0];
            end
            
            % Calcolo matrie di rotazione
            R=RiverNetwork.angolo2matriceRotazione(angolo);
            
            if iscell(coord1)==0        % caso polilinea unica
                coord_temp=[coord1(:,1)-polo(1),coord1(:,2)-polo(2)];
                coord2=(R*coord_temp')';
                coord2=[coord2(:,1)+polo(1)+vettore_distanza(1),coord2(:,2)+polo(2)+vettore_distanza(2)];
            else                        % caso polilinee multiple
                coord2=cell(size(coord1));
                for i=1:length(coord1)
                    coord_temp=[coord1{i}(:,1)-polo(1),coord1{i}(:,2)-polo(2)];
                    coord2{i}=(R*coord_temp')';
                    coord2{i}=[coord2{i}(:,1)+polo(1)+vettore_distanza(1),coord2{i}(:,2)+polo(2)+vettore_distanza(2)];
                end
            end
            
        end
        
        
        function R=angolo2matriceRotazione(angolo)
            
            % R=angolo2matriceRotazione(angolo)
            %
            % Costruisce la matrice di rotazione corrisponente a un dato angolo.
            % INPUT
            %   angolo = angolo di rotazione [rad]
            % OUTPUT
            %   R = matrice di rotazione
                        
            R=[cos(angolo) -sin(angolo); sin(angolo) cos(angolo)];
            
        end
        
        
        function R=vettori2rotazione(v1,v2)
            
            % R=vettori2rotazione(v1,v2)
            %
            % Calcola la matrice di rotazione in R2 che ruota il vettore v1 sul vettore v2.
            % INPUT
            %   v1 = primo vettore
            %   v2 = secondo vettore
            % OUTPUT
            %   R = matrice di rotazione
            
            v1=v1/sqrt(sum(v1(:).^2));
            v2=v2/sqrt(sum(v2(:).^2));
            R=[v1(1)*v2(1)+v1(2)*v2(2) v2(1)*v1(2)-v1(1)*v2(2); v1(1)*v2(2)-v2(1)*v1(2) v1(1)*v2(1)+v1(2)*v2(2)];
            
        end
        
        
        function angolo=vettori2angolo(v1,v2)
            
            % angolo=vettori2angolo(v1,v2)
            %
            % Calcola l'angolo tra due vettori.
            % INPUT
            %   v1 = primo vettore
            %   v2 = secondo vettore
            % OUTPUT
            %   angolo = angolo tra i due vettori [rad]
            
            angolo=atan2(v1(1)*v2(2)-v2(1)*v1(2),v1(1)*v2(1)-v1(2)*v2(2));
            
        end
        
        
        function writeCsv(A, nome_file, separatore)
            
            % writeCsv(A, nome_file, separatore)
            %
            % Scrive una matrice su un file .csv.
            % INPUT
            %   A = matrice numerica
            %   nome_file = nome del file .csv
            %   separatore = carattere per separare i valori (OPZIONALE, se non specificato = ',')

            
            % Controllo input
            if nargin==2
                separatore=',';
            end
            
            % Creazione del file
            fid=fopen(nome_file,'w');
            m=size(A,1);
            righe=cell(m,1);
            for i=1:m
                righe{i}=sprintf(['%u',separatore],A(i,1:end-1));
                righe{i}=[righe{i},sprintf('%u',A(i,end))];  % ultimo elemento della riga
            end
            fprintf(fid,'%s\n',righe{:});
            fclose(fid);
            
        end
        
        
        function [mappa,x,y,flag_errore]=letturaRaster(input_mappa,nome_variabile)
            
            % [mappa,x,y,flag_errore]=letturaRaster(input_mappa,nome_variabile)
            %
            % Lettura di una mappa, eventualmente da file raster.
            % INPUT
            %   input_mappa = matrice oppure nome di un file asciigrid oppure geotiff
            %   nome_variabile = nome della variabile che viene letta
            % OUTPUT
            %   mappa = mappa della variabile
            %   x = vettore delle longitudini
            %   y = vettore delle latitudini
            %   flag_errore = 0 : lettura riuscita, 1 : errore nella lettura
            
            
            flag_errore=0;
            [mappa,x,y]=deal([]);
            if isstruct(input_mappa) && ~ischar(input_mappa)    % struttura mappa
                if min(size(input_mappa.mappa))>1
                    mappa=input_mappa.mappa;
                    if isfield(input_mappa,'x')
                        x=input_mappa.x;
                    else
                        x=[];
                    end
                    if isfield(input_mappa,'y')
                        y=input_mappa.y;
                    else
                        y=[];
                    end
                else
                    keyboard
                    disp(['ERRORE nell''input ',nome_variabile,': è una variabile numerica ma non è una matrice.'])
                end
            elseif ischar(input_mappa)                          % lettura da file
                if exist(input_mappa,'file')==0
                    disp(['ERRORE nell''input ',nome_variabile,': file ',input_mappa,' NON TROVATO.']);
                    flag_errore=1;
                    return;
                end
                switch input_mappa(end-2:end)
                    case {'tif','tiff'}
                        [mappa,R]=geotiffread(input_mappa); %#ok<ASGLU>
                        nomi_lonlat={'LongitudeLimits','LatitudeLimits','CellExtentInLongitude','CellExtentInLatitude'};
                        nomelon=nomi_lonlat{1};
                        nomelat=nomi_lonlat{2};
                        nomedx=nomi_lonlat{3};
                        if length(nomi_lonlat)==4
                            nomedy=nomi_lonlat{4};
                            flag_dy=1;
                        else
                            flag_dy=0;
                        end
                        eval(['dx=R.',nomedx,';']);
                        if flag_dy==1
                            eval(['dy=R.',nomedy,';']);
                        else
                            dy=dx; %#ok<NODEF>
                        end
                        eval(['lon=R.',nomelon,';']);
                        eval(['lat=R.',nomelat,';']);
                        x1=min(lon); x2=max(lon);
                        y1=min(lat); y2=max(lat);
                        x=x1+dx/2:dx:x2-dx/2;
                        y=y1+dy/2:dy:y2-dy/2;
                    case {'asc','txt'}
                        [mappa,R]=arcgridread(input_mappa);
                        [n,m]=size(mappa);
                        dx=abs(R(2,1)); dy=abs(R(1,2));
                        x1=R(3,1)+dx; y2=R(3,2)-dy;
                        x=x1:dx:x1+(m-1)*dx;
                        y=y2-(n-1)*dy:dy:y2;
                    otherwise
                        disp(['ERRORE nell''input ',nome_variabile,': deve essere il nome di un raster .tif o .asc/.txt']);
                        flag_errore=1;
                end
            else
                disp(['ERRORE nell''input ',nome_variabile,': deve essere una matrice o il nome di un raster .tif o .asc/.txt']);
                flag_errore=1;
            end
        end
        
                
        function mat2geotiff(nome_file,mappa,x,y,flag_map)
            
            % mat2geotiff(nome_file,mappa,x,y,flag_map)
            %
            % Scrittura di una matrice in un file geotiff.
            % INPUT
            %   nome_file = nome del file di output
            %   mappa = mappa da scrivere
            %   x = vettore delle longitudini
            %   y = vettore delle latitudini
            %   flag_map = 0 : coordinate geografiche (DEFAULT), 1 : coordinate proiettate

            
            % Controllo input
            if nargin==4
                flag_map=0;      % coordinate geografiche
            end
            
            % risoluzione della griglia
            dx=abs(x(2)-x(1));
            dy=abs(y(2)-y(1));
            
            if flag_map==0       % coordinate geografiche
                R=georefcells(double([min(y)-dy/2 max(y)+dy/2]),double([min(x)-dx/2 max(x)+dx/2]),size(mappa),'ColumnsStartFrom','north');
                geotiffwrite(nome_file,mappa,R,'TiffTags',struct('Compression',Tiff.Compression.Deflate));
            elseif flag_map==1   % coordinate proiettate
                R=maprefcells(double([min(x)-dx/2 max(x)+dx/2]),double([min(y)-dy/2 max(y)+dy/2]),size(mappa),'ColumnsStartFrom','north');
                geotiffwrite(nome_file,mappa,R,'TiffTags',struct('Compression',Tiff.Compression.Deflate),'CoordRefSysCode',32633);
            end
            
        end
        
        
        function mat2rasterasc(nome_file,mappa,x,y,nodata)
            
            % mat2rasterasc(nome_file,mappa,x,y,nodata)
            %
            % Scrittura di una mappa in un file raster ascii.
            % INPUT
            %   nome_file = nome del file raster ascii
            %   mappa = mappa da scrivere
            %   x = vettore delle longitudini
            %   y = vettore delle latitudini
            %   nodata = valore nodata (OPZIONALE, se non specificato = -9999)
            
            
            % Controllo input
            if nargin==4
                nodata=-9999;
            end
            
            % Header
            mappa(isnan(mappa))=nodata;
            [nrows,ncols]=size(mappa);
            dx=abs(x(2)-x(1));
            xll=min(x)-dx/2;
            yll=min(y)-dx/2;
            fid=fopen(nome_file,'w+');
            fprintf(fid,'ncols         %g\n',ncols);
            fprintf(fid,'nrows         %g\n',nrows);
            fprintf(fid,'xllcorner     %4.12f\n',xll);
            fprintf(fid,'yllcorner     %4.12f\n',yll);
            fprintf(fid,'cellsize      %4.12f\n',dx);
            fprintf(fid,'NODATA_value  -9999\n');
            % scrittura della mappa
            for i=1:nrows
                fprintf(fid,'%2.5f ',mappa(i,:));
                fprintf(fid,'\n');
            end
            fclose(fid);
            
        end
        
        
        function flag_errore=scritturaRaster(x,y,mappa,nome_file)
            
            % flag_errore=scritturaRaster(x,y,mappa,nome_file)
            % 
            % Scrittura di una mappa in un file raster
            % INPUT
            %   x = vettore delle longitudini
            %   y = vettore delle latitudini
            %   mappa = mappa da scrivere
            %   nome_file = nome del file raster da scrivere
            % OUTPUT
            %   flag_errore = 0 : scrittura effettuata, 1 : errore nella
            %   scrittura
            
            
            flag_errore=0;
            switch nome_file(end-2:end)
                case {'tif','tiff'}
                    RiverNetwork.mat2geotiff(nome_file,mappa,x,y,0);
                case {'asc','txt'}
                    RiverNetwork.mat2rasterasc(nome_file,mappa,x,y,-9999)
                otherwise
                    disp(['ERRORE nell''input ',nome_file,': deve essere il nome di un file .tif/.tiff o .asc/.txt']);
                    flag_errore=1;
            end
                
        end
      
        
        function figureScreenRatio(coord_punti)
            
            % figureScreenRatio(coord_punti)
            %
            % Setta le dimensioni ottimali della figura in base ai punti da
            % plottare e alle dimensioni dello schermo.
            % INPUT
            %   coord_punti = matrice n x 2 con le coordinate di tutti i punti da plottare
            
            
            % Dimensioni schermo
            set(0,'units','pixels');
            dimensioni_schermo=get(0,'screensize');
            nrows_screen=dimensioni_schermo(4); ncols_screen=dimensioni_schermo(3);
            finestra=[min(coord_punti(:,1)) max(coord_punti(:,1)) min(coord_punti(:,2)) max(coord_punti(:,2))];
            if finestra(2)-finestra(1)>finestra(4)-finestra(3)
                xmin=finestra(1); xmax=finestra(2);
                Ymedio=(finestra(3)+finestra(4))/2;
                Dy=(xmax-xmin)*nrows_screen/ncols_screen;
                ymin=Ymedio-Dy/2; ymax=Ymedio+Dy/2;
            else
                ymin=finestra(3); ymax=finestra(4);
                Xmedio=(finestra(1)+finestra(2))/2;
                Dx=(ymax-ymin)*ncols_screen/nrows_screen;
                xmin=Xmedio-Dx/2; xmax=Xmedio+Dx/2;
            end
            vertici=[[xmin NaN xmax NaN xmax NaN xmin]',[ymin NaN ymin NaN ymax NaN ymax]'];
            
            % plotta i contorni (bianchi) della figura
            plot(vertici(:,1),vertici(:,2),'w');
            axis image;
            
        end
        
        
        function isEqual = confrontaValori(valore1,valore2)
            
            % isEqual = confrontaValori(valore1, valore2)
            %
            % Funzione ricorsiva per confrontare due valori (comprese le struct).
            % INPUT
            %   valore1 = variabile 1
            %   valore2 = variabile 2
            % OUTPUT
            %   isEqual = flag, 1 : le variabili sono identiche, 2 : le variabili sono diverse
            
            
            isEqual=true;
            
            if ischar(valore1)
                if ~isequal(valore1,valore2)
                    isEqual=false;
                end
                return
            end
            
            
            % Se uno dei valori è una struct, confronta i campi
            if isstruct(valore1) && isstruct(valore2)
                
                % Confronta i campi delle struct
                campi1=fieldnames(valore1);
                campi2=fieldnames(valore2);
                
                % Se i numeri di campi sono diversi, ritorna false
                if length(campi1)~=length(campi2)
                    isEqual=false;
                    return;
                end
                
                % Confronta i campi di entrambe le struct
                for i=1:length(campi1)
                    try
                        if ~isfield(valore2,campi1{i})
                            isEqual=false;
                            return;
                        end
                        
                        for j=1:length(valore1)
                            if ~RiverNetwork.confrontaValori( valore1(j).(campi1{i}), valore2(j).(campi2{i}) )
                                isEqual=false;
                                return;
                            end
                        end
                        
                    catch
                        keyboard
                    end
                end
                isEqual=true;
                return;
            end
            
            % Se non sono uguali e non sono struct, ritorna false
            if isnumeric(valore1)
                if ~isequaln(valore1,valore2)
                    isEqual=false;
                    return
                end
            end
            
        end
        
        
        function indici_ramo=percorsoReticolo(pnt,ret,punto,to_node_pot,n_punti_inizializzazione)
                        
            % indici_ramo=percorsoReticolo(pnt,ret,punto,to_node_pot,n_punti_inizializzazione)
            %
            % Percorre un reticolo verso valle dalla cella "punto" alla cella "to_node_pot"
            % INPUT
            %   pnt = matrice dei puntatori
            %   ret = matrice del reticolo
            %   punto = indice matrice della cella di partenza
            %   to_node_pot = indice matrice della cella o delle celle di arrivo, il percorso si interrompe quando viene raggiunta la prima
            %   n_punti_inizializzazione = lunghezza massima iniziale del percorso (OPZIONALE, se non specificato = 100)
            % OUTPUT
            %   indici_ramo = indici matrice del percorso sul reticolo da "punto" a "to_node_pot" ordinati verso valle
            
            
            % Controllo input
            if nargin==4
                n_punti_inizializzazione=100;
            end
            
            
            [nrows,ncols]=size(pnt);
            to_node_pot=setdiff(to_node_pot,punto);
            [direzioni,P]=RiverNetwork.puntatori2direzioni;
            k=1;
            indici_ramo=NaN(n_punti_inizializzazione,1);
            indici_ramo(k)=punto;
            while sum(ismember(indici_ramo,to_node_pot))==0
                [ip,jp]=ind2sub([nrows,ncols],indici_ramo(k));                                          % coordinate (i,j) della cella attualmente più a valle del percorso
                if pnt(indici_ramo(k))<=0 || isnan(pnt(indici_ramo(k))) || pnt(indici_ramo(k))==P(2,2)  % condizione di interruzione
                    if pnt(indici_ramo(k))==P(2,2) && ret(indici_ramo(k))==1
                        indici_ramo=indici_ramo(1:k);
                    else
                        indici_ramo=indici_ramo(1:k-1);
                    end
                    break;
                else
                    % avanzamento del percorso di una cella verso valle
                    k=k+1;
                    indici_ramo(k)=sub2ind([nrows,ncols],ip+direzioni(pnt(indici_ramo(k-1)),1),jp+direzioni(pnt(indici_ramo(k-1)),2)); % %#ok<AGROW>
                end
            end
            indici_ramo=indici_ramo(1:min(k,length(indici_ramo)));
            % Se il ramo è vuoto, è composto da una sola cella
            if isempty(indici_ramo)
                indici_ramo=punto;
            end
            
        end
        
                
        function [aste,coord_aste,aree_aste]=reticolo2aste(rami_bacino,aree_monte_rami,coord_rami,matrice_confluenze)
            
            % [aste,coord_aste,aree_aste]=reticolo2aste(rami_bacino,aree_monte_rami,coord_rami,matrice_confluenze)
            %
            % Ricostruisce le aste di un reticolo, fornendo anche coordinate e aree drenate, a partire dall'elenco
            % dei rami del bacino, le relative aree drenate e coordinate, e la matrice delle confluenze.
            % Un'asta è definita come una sequenza di rami che parte da una data foce/confluenza e procede
            % verso monte scegliendo a ogni confluenza il ramo con area drenata massima.
            % INPUT
            %   rami_bacino = elenco dei rami che fanno parte del bacino
            %   aree_monte_rami = aree di monte di tutti i rami [km2]
            %   coord_rami = cell array con le coordinate dei punti di tutti i rami
            %   matrice_confluenze = matrice che contiene 1 nell'elemento (i,j) se il ramo j è immediatamente a monte del ramo i
            % OUTPUT
            %   aste = cell array con la sequenza, per ogni asta, dei rami da valle verso monte
            %   coord_aste = coordinate dei punti dell'asta, da monte verso valle
            %   aree_aste = area drenata per ogni asta
       
            
            % selezione ramo foce
            %kc=0;
            aree_monte_rami_bacino=aree_monte_rami(rami_bacino);
            elenco_rami=rami_bacino;
            [massimo,indice]=max(aree_monte_rami_bacino);
            indici_massimo=find(aree_monte_rami_bacino==massimo);
            if length(indici_massimo)>1
                npunti=cellfun(@(x) size(x,1),coord_rami);
                ramo_valle=rami_bacino(indici_massimo(npunti(rami_bacino(indici_massimo))==1));
            else
                ramo_valle=rami_bacino(indice);
            end
            ramo=ramo_valle;
            if length(elenco_rami)==1   % il bacino è formato da un solo ramo
                
                aste={ramo};
                coord_aste={coord_rami{ramo}};
                aree_aste={aree_monte_rami(ramo)};
                
            else                        % caso generale con più rami
                
                k_asta=0;
                [aste,coord_aste,aree_aste]=deal(cell(length(rami_bacino),1));
                while isempty(elenco_rami)==0
                    
                    k_asta=k_asta+1;
                    
                    % costruzione asta
                    rami_asta=ramo;
                    rami_monte=ramo;
                    elenco_rami=setdiff(elenco_rami,ramo);
                    while isempty(rami_monte)==0
                        % selezione del ramo di monte con area drenata massima
                        rami_monte=find(matrice_confluenze(ramo,:));
                        if isempty(rami_monte)==0
                            aree_monte_rami_monte=aree_monte_rami(rami_monte);
                            [massimo,indice]=max(aree_monte_rami_monte); %#ok<ASGLU>
                            ramo=rami_monte(indice);
                            rami_asta=[rami_asta;ramo]; %#ok<AGROW>
                            elenco_rami=setdiff(elenco_rami,ramo);
                        end
                    end
                    if k_asta>1
                        rami_asta(rami_asta==ramo_valle)=[];
                    end
                    if isempty(elenco_rami)
                        aste{k_asta}=ramo;
                    else
                        aste{k_asta}=rami_asta;
                    end
                    
                    % coordinate asta
                    coord_asta=[];
                    for r=length(rami_asta):-1:1
                        coord_asta=[coord_asta;coord_rami{rami_asta(r)}]; %#ok<AGROW>
                    end
                    if size(coord_asta,1)>1
                        coord_diff=diff(coord_asta,1,1);
                        indici_coord_ripetute=find(coord_diff(:,1)==0 & coord_diff(:,2)==0);
                        if isempty(indici_coord_ripetute)==0
                            coord_asta(indici_coord_ripetute,:)=[]; %#ok<AGROW>
                        end
                    end
                    coord_aste{k_asta}=coord_asta;
                    
                    % area drenata dell'asta
                    aree_aste{k_asta}=aree_monte_rami(rami_asta(1));
                    
                    % prossima asta
                    [massimo,indice]=max(aree_monte_rami(elenco_rami)); %#ok<ASGLU>
                    ramo=elenco_rami(indice);
                    
                end
                aste=aste(1:k_asta);
                coord_aste=coord_aste(1:k_asta);
                aree_aste=aree_aste(1:k_asta);
            end
            
            
        end
        
        
        function [direzioni,P]=puntatori2direzioni(P)
            
            % [direzioni,P]=puntatori2direzioni(P)
            %
            % Converte i codici dei puntatori idrologici in una matrice con i delta_i e delta_j in coordinate matrice.
            % INPUT:
            %   P = matrice 3x3 con i puntatori idrologici (OPZIONALE, default = [7 8 9
            %                                                                     4 5 6
            %                                                                     1 2 3]
            % OUTPUT:
            %   direzioni = matrice 9 x 2 con i delta_i e delta_j corripondenti ai
            %               puntatori idrologici
            %   P = matrice 3x3 con i puntatori idrologici
            
            
            % Controllo input
            if nargin==0
                P=RiverNetwork.PUNTATORI;
            end
            
            
            % Spostamenti corrispondenti ai puntatori
            direzioni=NaN(9,2);
            DIR=[-1 -1;
                  0 -1;
                  1 -1;
                 -1  0;
                  0  0;
                  1  0;
                 -1  1;
                  0  1;
                  1  1];
            % riordinamento degli spostamenti se la matrice dei puntatori non è quella standard
            for i=1:numel(P)
                direzioni(P(i),:)=DIR(i,:);
            end
            
        end
        
        
    end
    
    
    
end
