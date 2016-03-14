// -*- coding: utf-8 -*-

public class Diner {
  public static void main(String args[]) {
    int nbSauvages = 100;                     // La tribu comporte 100 sauvages affamés
    int nbPortions = 5;                       // Le pôt contient 5 parts, lorsqu'il est rempli
    
    try {
	    nbSauvages = Integer.parseInt(args[0]);
	    nbPortions = Integer.parseInt(args[1]); 
	}
	catch(Exception e) {
	    System.err.println("Usage: java Diner <nb de sauvages> <taille du pot>");
	    System.exit(1);
	}
    
    System.out.println("Il y a " + nbSauvages + " sauvages.");
    System.out.println("Le pôt contient "+ nbPortions + " portions.");
    Pot pot = new Pot(nbPortions);
    new Cuisinier(pot).start();
    for (int i = 0; i < nbSauvages; i++) {
      new Sauvage(pot).start();
    }
  }
}  


class Sauvage extends Thread{
  public Pot pot;
  public Sauvage(Pot pot){
    this.pot = pot;
  }

  public void run(){
    while(true){
      System.out.println(getName() + ": J'ai faim!");
      pot.seServir();
      System.out.println(getName() + ": Je me suis servi et je vais manger!");
      try{sleep(1000);}
      catch(InterruptedException e){e.printStackTrace();}
    }
  }
}	


class Cuisinier extends Thread {
  public Pot pot;
  public Cuisinier(Pot pot){
    this.pot = pot;
  }

  public void run(){
    while(true){
      System.out.println("Cuisinier: Je suis endormi.");
      pot.remplir();
      try{sleep(1000);}
      catch(InterruptedException e){e.printStackTrace();}
    }
  }
}	


class Pot {
	private static final int maxPortions=5;
	volatile int nbPortions;
	
	public Pot(int n){nbPortions=n;}
	
	public synchronized void seServir(){
		while(nbPortions <= 0){
			System.out.println("Le pôt est vide !");
			System.out.println("Je réveille le cuisinier");
			notifyAll();
			System.out.println("Je m'endors...");
			try{wait();}
			catch(InterruptedException e){e.printStackTrace();}
		}
		System.out.println("Il y a une part disponible !");
		nbPortions--;			
	}
	
	public synchronized void remplir(){
		while(nbPortions>0){
			System.out.println("Je suis endomi.");
			try{wait();}
			catch(InterruptedException e){e.printStackTrace();}
		}
		System.out.println("Je suis réveillé !");
		System.out.println("Je cuisine...");
		nbPortions=maxPortions;
		System.out.println("Le pôt est plein !");
		notifyAll();
		System.out.println("Je me rendors.");
	}
}

