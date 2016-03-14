// -*- coding: utf-8 -*-

/*
 On veut comparer les performances de:
 - synchronized
 - Lock
 - ReadWriteLock (mais aussi, plus tard, le stamp lock)
lorsqu'il y a 99% de lectures et 1% d'écritures dans un tableau.

La Javadoc dit à propos de ReentrantReadWriteLock:

« ReentrantReadWriteLocks can be used to improve concurrency in some
uses of some kinds of Collections. This is typically worthwhile only
when the collections are expected to be large, accessed by more reader
threads than writer threads, and entail operations with overhead that
outweighs synchronization overhead. »

Il s 'agit ici d'illustrer le gain et le surcoût potentiel de ces
verrous.
*/


import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;
import java.util.concurrent.locks.ReentrantReadWriteLock;
import java.util.concurrent.locks.StampedLock;
    
import java.util.concurrent.ThreadLocalRandom;
/*
A random number generator isolated to the current thread. Like the
global Random generator used by the Math class, a ThreadLocalRandom
is initialized with an internally generated seed that may not
otherwise be modified. When applicable, use of ThreadLocalRandom
rather than shared Random objects in concurrent programs will
typically encounter much less overhead and contention. Use of
ThreadLocalRandom is particularly appropriate when multiple tasks
(for example, each a ForkJoinTask) use random numbers in parallel
in thread pools.
*/



public class Acteur extends Thread {
    static volatile String mode;
    static volatile int nbActeurs;
    static volatile int partIndividuelle;
    static volatile Thread[] T;
    static volatile int nbActions ;
    static private final int pourcentageEcriture = 1 ; // 1% d'écritures 99% de lectures

    static final int taille = 10_000 ;
    static private boolean[] drapeaux = new boolean[taille];
    // Un tableau de drapeaux partagés par tous les Acteurs
    int somme; // Il s'agira de calculer le nombre d'éléments à True dans le tableau drapeaux.

    static private final Object verrou = new Object(); // Pour le mode S=synchronized
    static private final ReentrantLock verrouLock = new ReentrantLock(); // Pour le mode L 
    static private final ReentrantLock verrouFair = new ReentrantLock(true); // Pour le mode F
    static private final ReentrantReadWriteLock rwl = new ReentrantReadWriteLock(); // Pour le mode RWL
    static private final Lock verrouLecture = rwl.readLock();   // On extrait le premier verrou
    static private final Lock verrouEcriture = rwl.writeLock();  // puis le second
    static private final StampedLock sl = new StampedLock();
    

    final int identite; // Chaque thread Acteur possède une identité propre.    
    Acteur(int identite) {
	this.identite = identite ;
    }

    public static void main(String[] args) {
	if (args.length < 3) {
	    System.err.println 
		("Usage: java Acteur <nb_Acteurs> <nb_Actions> <mode>"); 
	    System.err.println 
		("       Modes possibles : S L F RWL STAMP"); 
	    System.exit(1); 
	}
	try { nbActeurs = Integer.parseInt(args[0]); } 
	catch(NumberFormatException nfe) { 
	    System.err.println 
		("Usage: java Acteur *nb_Acteurs* <nb_Actions> <mode>"); 
	    System.err.println(nfe.getMessage()); 
	    System.exit(1); 
	}
	try { nbActions = Integer.parseInt(args[1]); } 
	catch(NumberFormatException nfe) { 
	    System.err.println 
		("Usage: java Acteur <nb_Acteurs> *nb_Actions* <mode>"); 
	    System.err.println(nfe.getMessage()); 
	    System.exit(1); 
	}
	mode = args[2];
	partIndividuelle = nbActions / nbActeurs;
	
	T = new Thread[nbActeurs];
	for(int id=0; id<nbActeurs; id++){
	    T[id] = new Acteur(id);
	}

	String infos [] = {
	    "pour " + (nbActions/nbActeurs) * nbActeurs
		     + " actions avec " + nbActeurs + " threads.",
	    "soit " + nbActions / nbActeurs
		     + " actions par thread.",
	    "Mode d'action adopté: " + mode,
	    "Taille du tableau: " + taille };
	Chronometre t = new Chronometre(infos); // Lance un chronomètre
		
	for(int id=0; id<nbActeurs; id++) T[id].start();
	try{
	    for(int id=0; id<nbActeurs; id++){
		T[id].join();}
	} catch(InterruptedException e){e.printStackTrace();}
	
	t.stop(); // Stoppe le chronomètre
	t.affiche(nbActeurs, " threads"); // Afficher le temps de calcul

    }


    /*
      Les Acteurs modifient un élément du le tableau ou calculent
      le nombre d'éléments TRUE qui y sont stockés, selon plusieurs
      modes:
      - S: un verrou intrinsèque (synchronized) assure l'exclusion mutuelle
      - L: un verrou lock assure l'exclusion mutuelle de chaque action
      - F: un verrou lock équitable (fair) assure l'exclusion mutuelle
      - RWL: un verrou de lecture-écriture permet les lectures en parallèle
      - STAMP: utilisation d'un verrou RWL avec tentative de lecture optimiste
    */

    public void run(){
	if (mode.equals("S")) run_S();
	else if (mode.equals("L")) run_L();
	else if (mode.equals("F")) run_F();
	else if (mode.equals("RWL")) run_RWL();
	else if (mode.equals("STAMP")) run_STAMP();
	else {
	    System.err.println 
		("Usage: java Acteur <nb_Acteurs> <nb_Actions> *mode*"); 
	    System.err.println 
		("       Modes possibles : S L F RWL STAMP"); 
	    System.exit(1); 
	}
    }

    public void run_S() {
	for (int i = 1;i<=partIndividuelle;i++){
		if (ThreadLocalRandom.current().nextInt(10)<pourcentageEcriture) { // Ecriture
		    synchronized(verrou){ // Modification aléatoire d'un élément aléatoire du tableau			
			drapeaux[ThreadLocalRandom.current().nextInt(taille)] =
			    ThreadLocalRandom.current().nextBoolean() ;
		    }
		}
		else { // Lecture
		    synchronized(verrou){ // Calcul du nombre d'éléments TRUE dans le tableau
			somme = 0;
			for (int j = 0 ; j < taille; j++)
			    if (drapeaux[j]) somme++ ;
		    }
		}
	    }
	} 
    

    public void run_L() {
	for (int i = 1;i<=partIndividuelle;i++){
	    if (ThreadLocalRandom.current().nextInt(10)<pourcentageEcriture) { // Ecriture
		verrouLock.lock();
		try{
		    drapeaux[ThreadLocalRandom.current().nextInt(taille)] =
			ThreadLocalRandom.current().nextBoolean() ; 
		} finally { verrouLock.unlock(); }
	    }
	    else { // Lecture
		verrouLock.lock();
		try {
		    somme = 0;
		    for (int j = 0 ; j < taille; j++)
			if (drapeaux[j]) somme++ ;
		} finally { verrouLock.unlock(); }
	    }
	} 
    }
    
    public void run_F(){
	for (int i = 1;i<=partIndividuelle;i++){
	    if (ThreadLocalRandom.current().nextInt(101)<pourcentageEcriture) { // Ecriture
		verrouFair.lock(); 
		try{
		    drapeaux[ThreadLocalRandom.current().nextInt(taille)] =
		    ThreadLocalRandom.current().nextBoolean() ;
		} finally { verrouFair.unlock(); } 
	    }
	    else { // Lecture
		verrouFair.lock();
		try {
		    somme = 0;
		    for (int j = 0 ; j < taille; j++)
			if (drapeaux[j]) somme++ ;
		} finally { verrouFair.unlock(); }
	    }
	} 
    }

    public void run_RWL(){
	for (int i = 1;i<=partIndividuelle;i++){
	    if (ThreadLocalRandom.current().nextInt(101)<pourcentageEcriture) { // Ecriture
		verrouEcriture.lock();
		try {
		    drapeaux[ThreadLocalRandom.current().nextInt(taille)] =
		    ThreadLocalRandom.current().nextBoolean() ; 
		} finally { verrouEcriture.unlock(); }
	    }
	    else { // Lecture
		verrouLecture.lock();
		try {
		    somme = 0;
		    for (int j = 0 ; j < taille; j++)
			if (drapeaux[j]) somme++ ;
		} finally { verrouLecture.unlock(); }
	    }
	} 
    }
    
    public void run_STAMP(){
	long stamp ;
	for (int i = 1;i<=partIndividuelle;i++){
	    if (ThreadLocalRandom.current().nextInt(101)<pourcentageEcriture) { // Ecriture
		stamp = sl.writeLock();
		try {
		    drapeaux[ThreadLocalRandom.current().nextInt(taille)] =
			ThreadLocalRandom.current().nextBoolean() ; 
		} finally { sl.unlockWrite(stamp); }
	    }
	    else { // Lecture
		stamp = sl.tryOptimisticRead();
		somme = 0;
		for (int j = 0 ; j < taille; j++) if (drapeaux[j]) somme++ ;
		if (!sl.validate(stamp)) {
		    stamp = sl.readLock();
		    try{
			somme = 0;
			for (int j = 0 ; j < taille; j++) if (drapeaux[j]) somme++ ;
		    } finally { sl.unlockRead(stamp);}
		}
	    }
	}
    }
}

/*
> make
javac *.java
> java Acteur
Usage: java Acteur <nb_Acteurs> <nb_Actions> <mode>
       Modes possibles : S L F RWL STAMP
> java Acteur 4 100000 S
  #_CHRONO_#   Date du test : 30/01/16 02:49 sur une machine avec 8 coeurs.
  #_CHRONO_#   Temps de calcul en ms. 
  #_CHRONO_#   pour 100000 actions avec 4 threads.
  #_CHRONO_#   soit 25000 actions par thread.
  #_CHRONO_#   Mode d'action adopté: S
  #_CHRONO_#   Taille du tableau: 10000
4 1982  #_CHRONO_#  1982 ms.  pour 4  threads
> java Acteur 4 100000 L
  #_CHRONO_#   Date du test : 30/01/16 02:49 sur une machine avec 8 coeurs.
  #_CHRONO_#   Temps de calcul en ms. 
  #_CHRONO_#   pour 100000 actions avec 4 threads.
  #_CHRONO_#   soit 25000 actions par thread.
  #_CHRONO_#   Mode d'action adopté: L
  #_CHRONO_#   Taille du tableau: 10000
4 1877  #_CHRONO_#  1877 ms.  pour 4  threads
> java Acteur 4 100000 RWL
  #_CHRONO_#   Date du test : 30/01/16 02:49 sur une machine avec 8 coeurs.
  #_CHRONO_#   Temps de calcul en ms. 
  #_CHRONO_#   pour 100000 actions avec 4 threads.
  #_CHRONO_#   soit 25000 actions par thread.
  #_CHRONO_#   Mode d'action adopté: RWL
  #_CHRONO_#   Taille du tableau: 10000
4 342  #_CHRONO_#  342 ms.  pour 4  threads
> java Acteur 4 100000 STAMP
  #_CHRONO_#   Date du test : 30/01/16 02:49 sur une machine avec 8 coeurs.
  #_CHRONO_#   Temps de calcul en ms. 
  #_CHRONO_#   pour 100000 actions avec 4 threads.
  #_CHRONO_#   soit 25000 actions par thread.
  #_CHRONO_#   Mode d'action adopté: STAMP
  #_CHRONO_#   Taille du tableau: 10000
4 362  #_CHRONO_#  362 ms.  pour 4  threads
> java Acteur 4 100000 F
  #_CHRONO_#   Date du test : 30/01/16 02:51 sur une machine avec 8 coeurs.
  #_CHRONO_#   Temps de calcul en ms. 
  #_CHRONO_#   pour 100000 actions avec 4 threads.
  #_CHRONO_#   soit 25000 actions par thread.
  #_CHRONO_#   Mode d'action adopté: F
  #_CHRONO_#   Taille du tableau: 10000
4 1427  #_CHRONO_#  1427 ms.  pour 4  threads
*/

