// -*- coding: utf-8 -*-

public class monThread extends Thread {
  public static void main(String[] args) {
    monThread p1 = new monThread();
    monThread p2 = new monThread();		
    p1.start(); p2.start();
  }
  public void run() {
      for (int i = 1;i<=1000;i++) {
	  System.out.println(i + " " + getName());
	  try{this.sleep(100);} 
	  catch(InterruptedException e){ e.printStackTrace(); } 
      }
  }
}
