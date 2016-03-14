// -*- coding: utf-8 -*-
import java.util.ArrayList;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.*;

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

public class MonteCarlo {  
    static long nbTirages = 1000000000 ;
    static int nbThreads = Runtime.getRuntime().availableProcessors() ;
    // A priori, on lance un thread par coeur disponible

    public static void main(String[] args) {
      if (args.length > 0) {    
	  try { nbTirages = Long.parseLong(args[0]); } 
	  catch(NumberFormatException nfe) { 
	      System.err.println 
		  ("Usage : java MonteCarlo <nb de tirages> ..."); 
	      System.exit(1); 
	  }
      }
      System.out.println("Il y a " + nbThreads + " coeurs disponibles.");
      if (args.length > 1) {    
	  try { nbThreads = Integer.parseInt(args[1]); } 
	  catch(NumberFormatException nfe) { 
	      System.err.println 
		  ("Usage : java MonteCarlo <nb de tirages> <nb de threads>"); 
	      System.exit(1); 
	  }
      }
      
      String infos [] = {
	  "pour " + (nbTirages/nbThreads) * nbThreads
	  + " actions avec " + nbThreads + " threads.",
	  "soit " + nbTirages / nbThreads
	  + " actions par thread.",
	  "MODE: Futures avec arrêt de l'exécuteur." };
      Chronometre t = new Chronometre(infos); // Lance un chronomètre

      // Création du réservoir formé de nbThreads esclaves
      ExecutorService executeur = Executors.newFixedThreadPool(nbThreads);
      // Remplissage de la liste des tâches      
      ArrayList<Future<Long>> resultatsAVenir = new ArrayList<Future<Long>>();
      for (int j = 0; j < nbThreads ; j++){
 	  MultipleLancer tache = new MultipleLancer( nbTirages/nbThreads );
	  Future<Long> resultatSoumis = executeur.submit(tache);
	  resultatsAVenir.add(resultatSoumis);
      }
      executeur.shutdown(); // Il n'y a plus aucune tâche à soumettre

      // Il faut maintenant attendre la fin de chaque calcul pour sommer les résultats
      // La méthode précédente (utilisée avec les ThreadPools) fonctionne encore ici:
	while (! executeur.isTerminated() ) {
	  try{ executeur.awaitTermination(1, TimeUnit.SECONDS); }
	  catch (InterruptedException e) {e.printStackTrace();}
	  System.out.print("#") ;	    
        }

      Future<Long> resultatAttendu;
      long tiragesDansLeDisque = 0 ;
      /* 
      // L'alternative consisterait si on veut à attendre la fin de chaque tâche:
      for (int j = 0; j < nbThreads ; j++){	  
	  resultatAttendu = resultatsAVenir.get(j);
	  try {
	      while (!resultatAttendu.isDone() && !resultatAttendu.isCancelled()) {
		  System.out.print("#"); Thread.sleep(500);
	      } // Ce n'est pas vraiment une attente active mais il y a mieux...
	      if (resultatAttendu.isCancelled()) {
		  System.out.println("\nL'exécution d'une tâche a été annulée!");
		  System.exit(1);
	      }
	  } catch(Exception ignore) {}
      }
      */
      
      for (int j = 0; j < nbThreads ; j++){	  
	  resultatAttendu = resultatsAVenir.get(j);
	  try {
	      tiragesDansLeDisque += resultatAttendu.get();
	  } catch(Exception ignore) {}
      }
      double resultat = (double) tiragesDansLeDisque / nbTirages ;

      System.out.println() ;	    
      t.stop(); // Stoppe le chronomètre
      t.affiche(nbThreads, " threads"); // Afficher le temps de calcul

      System.out.println("Estimation de Pi/4: " + resultat) ;
      System.out.println("Pourcentage d'erreur: "
			 + 100 * Math.abs(resultat-Math.PI/4)/(Math.PI/4)
			 + " %");
    }
}


class MultipleLancer implements Callable<Long>{
    long nbTirages;
    long tiragesDansLeDisque = 0 ;

    MultipleLancer(long part){
	nbTirages = part;
    }
    
    public Long call(){
	double x, y;
	for (long i = 0; i < nbTirages; i++) {
	    x = ThreadLocalRandom.current().nextDouble(1);
	    y = ThreadLocalRandom.current().nextDouble(1);
	    if (x * x + y * y <= 1) tiragesDansLeDisque++ ;
	}
	return tiragesDansLeDisque;
    }
}

/*
> make
javac *.java
> java MonteCarlo 100000000 4
Il y a 8 coeurs disponibles.
  #_CHRONO_#   Date du test : 30/01/16 11:34 sur une machine avec 8 coeurs.
  #_CHRONO_#   Temps de calcul en ms. 
  #_CHRONO_#   pour 100000000 actions avec 4 threads.
  #_CHRONO_#   soit 25000000 actions par thread.
  #_CHRONO_#   MODE: Futures avec arrêt de l'exécuteur.
#
4 223  #_CHRONO_#  223 ms.  pour 4  threads
Estimation de Pi/4: 0.7854177
Pourcentage d'erreur: 0.002487477493862049 %
> java MonteCarlo 1000000000 4
Il y a 8 coeurs disponibles.
  #_CHRONO_#   Date du test : 30/01/16 11:34 sur une machine avec 8 coeurs.
  #_CHRONO_#   Temps de calcul en ms. 
  #_CHRONO_#   pour 1000000000 actions avec 4 threads.
  #_CHRONO_#   soit 250000000 actions par thread.
  #_CHRONO_#   MODE: Futures avec arrêt de l'exécuteur.
###
4 2064  #_CHRONO_#  2064 ms.  pour 4  threads
Estimation de Pi/4: 0.785422185
Pourcentage d'erreur: 0.0030585254296826487 %
> java MonteCarlo 10000000000 4
Il y a 8 coeurs disponibles.
  #_CHRONO_#   Date du test : 30/01/16 11:34 sur une machine avec 8 coeurs.
  #_CHRONO_#   Temps de calcul en ms. 
  #_CHRONO_#   pour 10000000000 actions avec 4 threads.
  #_CHRONO_#   soit 2500000000 actions par thread.
  #_CHRONO_#   MODE: Futures avec arrêt de l'exécuteur.
######################
4 21066  #_CHRONO_#  21066 ms.  pour 4  threads
Estimation de Pi/4: 0.7853946681
Pourcentage d'erreur: 4.4503509317272706E-4 %
> 

*/

    
