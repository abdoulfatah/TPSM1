// -*- coding: utf-8 -*-

import java.lang.Thread; 
import java.lang.Math;

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


public class MonteCarlo extends Thread {
    static volatile int nombreDeThreads = 2;
    static volatile int nombreDeTirages = 1000 ; 

    static volatile int tiragesDansLeDisque = 0 ;

    public static void main (String args[]) {
      if (args.length>0) {
	  try { nombreDeTirages = Integer.parseInt(args[0]); } 
	  catch(NumberFormatException e) { 
	      System.err.println 
	      ("Usage : java MonteCarlo <nb de tirages>"); 
	      System.exit(1); 
	  }
      }

      if (args.length>1) {
	  try { nombreDeThreads = Integer.parseInt(args[1]); } 
	  catch(NumberFormatException e) { 
	      System.err.println 
	      ("Usage : java MonteCarlo <nb de tirages> <nb de threads>"); 
	      System.exit(1); 
	  }
      }


      String infos [] = {
	  "pour " + (nombreDeTirages/nombreDeThreads) * nombreDeThreads
	  + " actions avec " + nombreDeThreads + " threads.",
	  "soit " + nombreDeTirages / nombreDeThreads
	  + " actions par thread.",
	  "MODE: Incrémentation d'une variable synchronisée." };
      Chronometre t = new Chronometre(infos); // Lance un chronomètre

      Thread[] T = new Thread[nombreDeThreads];
      for(int i=0; i<nombreDeThreads; i++){
	  T[i]=new MonteCarlo();
	  T[i].start();
      }
      for(int i=0; i<nombreDeThreads; i++){
	  try{ T[i].join();}
	  catch(InterruptedException e){e.printStackTrace();}
      }
      double resultat = (double) tiragesDansLeDisque / nombreDeTirages ;

      t.stop(); // Stoppe le chronomètre
      t.affiche(nombreDeThreads, " threads"); // Afficher le temps de calcul
     
      System.out.println("Estimation de Pi/4: " + resultat) ;
      System.out.println("Pourcentage d'erreur: "
			 + 100 * Math.abs(resultat-Math.PI/4)/(Math.PI/4)
			 + " %");
    }

    public void run(){
	double x, y;
	for (long i = 0; i < nombreDeTirages/nombreDeThreads; i++) {
	    x = ThreadLocalRandom.current().nextDouble(1);
	    y = ThreadLocalRandom.current().nextDouble(1);
	    if (x * x + y * y <= 1) {
		synchronized(MonteCarlo.class) {
		    tiragesDansLeDisque++ ;
		}
	    }
	}
    }
}

/*
> make
javac *.java
> java MonteCarlo 10000000
  #_CHRONO_#   Date du test : 30/01/16 11:01 sur une machine avec 8 coeurs.
  #_CHRONO_#   Temps de calcul en ms. 
  #_CHRONO_#   pour 10000000 actions avec 2 threads.
  #_CHRONO_#   soit 5000000 actions par thread.
  #_CHRONO_#   MODE: Incrémentation d'une variable synchronisée.
2 501  #_CHRONO_#  501 ms.  pour 2  threads
Estimation de Pi/4: 0.7852921
Pourcentage d'erreur: 0.01350441118800497 %
> java MonteCarlo 10000000 4
  #_CHRONO_#   Date du test : 30/01/16 11:02 sur une machine avec 8 coeurs.
  #_CHRONO_#   Temps de calcul en ms. 
  #_CHRONO_#   pour 10000000 actions avec 4 threads.
  #_CHRONO_#   soit 2500000 actions par thread.
  #_CHRONO_#   MODE: Incrémentation d'une variable synchronisée.
4 515  #_CHRONO_#  515 ms.  pour 4  threads
Estimation de Pi/4: 0.7853587
Pourcentage d'erreur: 0.00502463582007939 %
> java MonteCarlo 100000000 4
  #_CHRONO_#   Date du test : 30/01/16 11:02 sur une machine avec 8 coeurs.
  #_CHRONO_#   Temps de calcul en ms. 
  #_CHRONO_#   pour 100000000 actions avec 4 threads.
  #_CHRONO_#   soit 25000000 actions par thread.
  #_CHRONO_#   MODE: Incrémentation d'une variable synchronisée.
4 4934  #_CHRONO_#  4934 ms.  pour 4  threads
Estimation de Pi/4: 0.78543227
Pourcentage d'erreur: 0.0043425875105471716 %
*/
