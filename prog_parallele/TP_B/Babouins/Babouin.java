// -*- coding: utf-8 -*-

enum Cote { EST, OUEST }                   // Le canyon possède un côté EST et un côté OUEST

class Babouin extends Thread{
  private static int numeroSuivant = 0;    // Compteur partagé par tous les babouins
  private int numero;                      // Numéro du babouin
  private Corde corde;                     // Corde utilisée par le babouin
  private Cote origine;                    // Côté du canyon où apparaît le babouin: EST ou OUEST
  Babouin(Corde corde, Cote origine){      // Constructeur de la classe Babouin
    this.corde = corde;                    // Chaque babouin peut utiliser la corde
    this.origine = origine;                // Chaque babouin apparaît d'un côté précis du canyon
    numero = ++numeroSuivant;              // Chaque babouin possède un numéro distinct
  }
  public void run(){
     System.out.println("Le babouin " + numero + " arrive sur le côté " + origine + " du canyon.");
    corde.saisir(origine);                 // Pour traverser, le babouin saisit la corde
    System.out.println("Le babouin " + numero +
                        " commence à traverser sur la corde en partant de l'" + origine + ".");
    try { sleep(5000); } catch(InterruptedException e){} // La traversée ne dure que 5 secondes
     System.out.println("Le babouin " + numero + " a terminé sa traversée.");
    corde.lacher(origine);                 // Arrivé de l'autre côté, le babouin lâche la corde
    System.out.println("Le babouin " + numero + " a lâché la corde et s'en va.");
  }
  public static void main(String[] args){ 
    Corde corde = new Corde();    // La corde relie les deux côtés du canyon
    for (int i = 1; i < 20; i++){
      try { Thread.sleep(500); } catch(InterruptedException e){}		    
      if (Math.random() >= 0.5){
        new Babouin(corde, Cote.EST).start();    // Création d'un babouin à l'est du canyon
      } else {
        new Babouin(corde, Cote.OUEST).start();  // Création d'un babouin à l'ouest du canyon
      }
    } // Une vingtaine de babouins sont répartis sur les deux côtés du canyon
  }
}

class Corde {
    private Cote sense=null;//sens correspond au cote d'origine du sens de traversee actuellement en vigueur
    private int nbSurCorde=0;
    private boolean blocage = false;//On passe ce bool a true seulement quand un babouin attend pour passer alors que le sens actuel est inverse au sien
    private Cote futurSense=null;//S'il y a un blocage, alors voici le sens qui devra etre adopte asap

    public synchronized void saisir(Cote origine){
	if(sense==null) sense=origine;//Si la corde est actuellement vide, on definit le sens de passage initial
	if(sense!=origine){
	    blocage = true;//Si on veut aller en sens inverse du sens de passage actuel, on demande un blocage asap
	    futurSense=origine;
	}
	while(nbSurCorde==5 || sense != origine || blocage){
	    try{wait();}
	    catch(InterruptedException e){e.printStackTrace();}
	}
	nbSurCorde++;
    }

    public synchronized void lacher(Cote origine){
	nbSurCorde--;
	if(nbSurCorde==0){
	    if(blocage){
		blocage = false;
		sense = futurSense;
		futurSense = null;
	    }
	    else sense=null;
	}
	notifyAll();
    }
}
