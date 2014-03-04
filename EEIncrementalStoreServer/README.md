AESIncrementalStore
===================
 * Introduzione
 * Come funziona
 * Quickstart

## Introduzione
Si tratta di un sistema di sincronizzazione dati tra un server JEE7 e dispositivi iOS. Si basa su alcune caratteristiche peculiari dei due ambienti, come:

 * Core Data e i modelli dati
 * NSIncrementalStore per i dati da aggiornare sul server e sincronizzare sul client
 * JPA 2.1 per:
  * Modello Dati
  * Grafi di relazioni
  * Indipendenza dallo storage
  
Sfruttando queste caratteristiche si possono tenere sincronizzati i device con lo storage centrale senza dover imparare nuove API o installare nuova infrastruttura oltre a quella JEE già consolidata.

## Come funziona
Il punto centrale è il modello dei dati, disegnato con l'editor standard di XCode. A questo dobbiamo aggiungere nelle "userInfo" alcune direttive che vengono poi usate per la generazione degli entity JPA e le loro associazioni. 
Gli entity così generati devono essere poi deployati, insieme ad alcune classi di supporto, su un container standard JEE7 usando lo WAR generato con il comando:

```
mvn package
```
A livello di protocollo, quando viene fatta la save sul MOC di CoreData lato client l'Incremental Sotre lancia una callback con argomento gli oggetti da "inserire", "aggiornare", "cancellare". Sulla base di questi insiemi viene creato un documento JSON di aggiornamento e passato ad un servizio JAX-RS del server, dove il JSON viene parsato e in base ai contenuti viene aggiornato il datastore centrale.
Alla fine di questa elaborazione al client vengono tornate le @Version corrette per la gestione dell'Optimistic Locking.

## Quickstart
 * Checkout del progetto
 * Disegno del modello dati tramite XCode (ed inserimento dati supplementari in userInfo)
 * Implementazione del client iOS con API standard CoreData
 * Partendo dal file XML di CoreData lanciamo il comando:
```
generate /path/to/codedata/model/file
``` 
che genera gli entity relativi al modello client disegnato.
 * Sul progetto server dove sono stati scritti gli entity generati lanciamo il comando:
```
mvn install
```
per generare lo WAR e far partire GlassFish Embedded già pronto a rispondere alle richieste di sincronizzazione.
 * Per la produzione possiamo deployare lo WAR generato allo step precedente su un qualsiasi container JEE7.

### Riferimenti:

 * [blahblah](https://github.com/blahblah) blah blah reference
