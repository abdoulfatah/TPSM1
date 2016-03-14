// -*- coding: utf-8 -*-

class Test {
    static Thread Cobaye, Observateur;

    public static void Affiche(){
	System.out.println("** Etats des threads: Cobaye = "
			   + String.format("%1$-14s",Cobaye.getState())
			 + "- Observateur = " + Observateur.getState());
    }

    public static void main(String[] args) throws InterruptedException {
	Cobaye = new Thread( new Runnable(){
		public void run() {
		    for(int i = 0; i < 10; i++){ Affiche(); }
		}
	    }
	    );

	Observateur = new Thread( new Runnable(){
		public void run() {
		    for(int i = 0; i < 10; i++){ Affiche(); }
		}
	    }
	    );
	
        System.out.println("** Début du test...");
	Cobaye.start();
	Observateur.start();
	Cobaye.join();
	Affiche();
	Observateur.join();
        System.out.println("** Fin du test...");
    }
}

/*
> java Test
** Début du test...
** Etats des threads: Cobaye = RUNNABLE      - Observateur = RUNNABLE
** Etats des threads: Cobaye = RUNNABLE      - Observateur = RUNNABLE
** Etats des threads: Cobaye = RUNNABLE      - Observateur = RUNNABLE
** Etats des threads: Cobaye = RUNNABLE      - Observateur = RUNNABLE
** Etats des threads: Cobaye = RUNNABLE      - Observateur = RUNNABLE
** Etats des threads: Cobaye = RUNNABLE      - Observateur = RUNNABLE
** Etats des threads: Cobaye = RUNNABLE      - Observateur = RUNNABLE
** Etats des threads: Cobaye = RUNNABLE      - Observateur = RUNNABLE
** Etats des threads: Cobaye = BLOCKED       - Observateur = RUNNABLE
** Etats des threads: Cobaye = RUNNABLE      - Observateur = RUNNABLE
** Etats des threads: Cobaye = RUNNABLE      - Observateur = RUNNABLE
** Etats des threads: Cobaye = RUNNABLE      - Observateur = RUNNABLE
** Etats des threads: Cobaye = RUNNABLE      - Observateur = RUNNABLE
** Etats des threads: Cobaye = RUNNABLE      - Observateur = RUNNABLE
** Etats des threads: Cobaye = RUNNABLE      - Observateur = RUNNABLE
** Etats des threads: Cobaye = RUNNABLE      - Observateur = RUNNABLE
** Etats des threads: Cobaye = RUNNABLE      - Observateur = RUNNABLE
** Etats des threads: Cobaye = BLOCKED       - Observateur = RUNNABLE
** Etats des threads: Cobaye = TERMINATED    - Observateur = RUNNABLE
** Etats des threads: Cobaye = TERMINATED    - Observateur = RUNNABLE
** Etats des threads: Cobaye = TERMINATED    - Observateur = RUNNABLE
** Fin du test...
*/
