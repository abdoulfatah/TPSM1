// -*- coding: utf-8 -*-

class Start {
    static Object objet = new Object();
    static Thread Cobaye, Observateur;
    static volatile int fin = 0; 

    public static void Affiche(){
	System.out.print("Etat du thread Cobaye: " + Cobaye.getState());
	if ( Cobaye.isInterrupted() )
	    { System.out.println(" (interrompu)."); }
	else
	    { System.out.println(" (non interrompu)."); }
    }

    public static void main(String[] args) throws InterruptedException {
	Cobaye = new Thread( new Runnable(){
		public void run() {
		    System.out.println( "** Le Cobaye démarre..." ) ;
		    while ( fin == 0 ); // Attente active!
		}
	    }
	    );

	Observateur = new Thread( new Runnable(){
		public void run(){
		    System.out.println("** L'Observateur démarre...");
		    Affiche();
		    Cobaye.start();
		    Affiche();
		    try{ Thread.sleep(1000) ;}
		    catch(InterruptedException e){}
		    Affiche();
		    fin = 1;
		    try{ Thread.sleep(1000) ;}
		    catch(InterruptedException e){}
		    Affiche();
		}
	    });
	
        System.out.println("** Début du test...");
	Observateur.start(); // C'est l'Observateur qui démarre le Cobaye
	Cobaye.join();
	Observateur.join();
        System.out.println("** Fin du test...");
    }
}

