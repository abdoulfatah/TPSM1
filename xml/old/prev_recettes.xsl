<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:fo="http://www.w3.org/1999/XSL/Format">
  <xsl:output name="defaut" method="html" version="4.0" encoding="iso-8859-1" indent="yes"/>
  <xsl:template match="/">
    <xsl:result-document href="index.html" format="defaut">
      <html>
	<head>
	  <title>Odelices</title>
	</head>
	<body>
	  <xsl:call-template name="page_accueil"/>
	</body>
      </html>
    </xsl:result-document>
    <!--<xsl:result-document href="recettes.html" format="defaut">
      <html>
	<head>
	  <title>Recettes</title>
	</head>
	<body>
	  <xsl:call-template name="recettes_court"/>
	  <xsl:call-template name="recettes"/>
	</body>
      </html>
      </xsl:result-document>-->
    <xsl:call-template name="recettes"/>
    <xsl:result-document href="ingredients.html" format="defaut">
      <html>
	<head>
	  <title>Ingrédients</title>
	</head>
	<body>
	  <xsl:call-template name="ingredients_court"/>
	  <xsl:call-template name="ingredients"/>
	</body>
      </html>
    </xsl:result-document>
    <xsl:result-document href="auteurs.html" format="defaut">
      <html>
	<head>
	  <title>Auteurs</title>
	</head>
	<body>
	  <xsl:call-template name="auteurs_court"/>
	  <xsl:call-template name="auteurs"/>
	</body>
      </html>
    </xsl:result-document>
    <!--</body>
	</html>-->
  </xsl:template>
  
  <!-- Page d'accueil du site -->
  <xsl:template name="page_accueil">
    <h1>Recettes of Doom</h1>
    <xsl:for-each select="objets/objet">
      <xsl:if test="@type = 'Cuisine'">
	<xsl:for-each select="info">
	  <xsl:if test="@nom = 'nom'">
	    <h2><xsl:value-of select="@value"/></h2>
	  </xsl:if>
	</xsl:for-each>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>
  
  <!--Liste des auteurs version courte-->
  <xsl:template name="auteurs_court">
    <h2>Index des auteurs</h2>
    <ul>
      <xsl:for-each select="objets/objet">
	<xsl:if test="@type = 'auteur'">
	  <xsl:for-each select="info">
	    <xsl:if test="@nom = 'idext'">
	      <li><a href="#{../@id}"><xsl:value-of select="@value"/></a></li>
	    </xsl:if>
	  </xsl:for-each>
	</xsl:if>
      </xsl:for-each>
    </ul>
  </xsl:template>
  
  <!-- Liste détaillée des auteurs -->
  <!-- Pour chaque auteur, son idext sert d'ancre pour accéder au tableau lui correspondant  -->
  <!-- Le tableau contient toutes les infos disponibles sauf son id (utilisécomme titre) -->
  <xsl:template name="auteurs">
    <h2>Liste des auteurs</h2>
    <xsl:for-each select="objets/objet">
      <xsl:if test="@type = 'auteur'">
	<table border="5">
	  <xsl:for-each select="info">
	    <xsl:if test="@nom='idext'">
	      <h3 id="{../@id}"><xsl:value-of select="@value"/></h3>
	    </xsl:if>
	    <xsl:if test="@nom='recette'">
	      <xsl:if test="/objets/objet[@id=current()/@value]">
		<tr>
		  <td><xsl:value-of select="@nom"/></td>
		  <td><a href="recettes.html#{@value}"><xsl:value-of select="/objets/objet[@id=current()/@value]/info[@nom='nom']/@value"/></a></td>
		</tr>
	      </xsl:if>
	    </xsl:if>
	    <xsl:if test="not(@nom = 'idext') and not(@nom = 'recette')">
	      <tr>
		<td><xsl:value-of select="@nom"/></td>
		<td><xsl:value-of select="@value"/></td>
	      </tr>
	    </xsl:if>
	  </xsl:for-each>
	</table>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>
  
  <!-- Liste des recettes version courte-->
  <xsl:template name="recettes_court">
    <h2>Index des recettes</h2>
    <ul>
      <xsl:for-each select="objets/objet">
	<xsl:if test="@type = 'recette'">
	  <li><a href="#{@id}">
	    <xsl:for-each select="info">
	      <xsl:if test="@nom = 'nom'">
		<xsl:value-of select="@value"/>
	      </xsl:if>
	    </xsl:for-each>
	  </a></li>
	</xsl:if>
      </xsl:for-each>
    </ul>
  </xsl:template>
  

  <!-- Liste détaillée des recettes -->
  <!-- Pour chaque recette, son id sert d'ancre pour accéder au tableau lui correspondant -->
  <!-- Pour chaque recette, le nom est indiqué en titre, hors du tableau -->
  <xsl:template name="recettes">
    <h2>Liste des recettes</h2>
    <xsl:for-each select="objets/objet">
      <xsl:if test="@type = 'recette'">
	<xsl:result-document href="html/recette_{@id}.html" format="defaut">
	  <html>
	    <head>
	      <title><xsl:value-of select="@id"/></title>
	    </head>
	    <body><html>
	      <head>
		<title>Recettes</title>
	      </head>
	      <body>
		<xsl:call-template name="recettes_court"/>
		<xsl:call-template name="recettes"/>
	      </body>
	    </html>
	    </body>
	  </html>
	  <h3 id="{@id}">
	    <xsl:for-each select="info">
	      <xsl:if test="@nom='nom'">
		<xsl:value-of select="@value"/>
	      </xsl:if>
	    </xsl:for-each>
	  </h3>
	  <table border="5">
	    <xsl:for-each select="info">
	      <xsl:if test="not(@nom = 'nom')">
		<tr>
		  <td><xsl:value-of select="@nom"/></td>
		  <xsl:if test="@nom='auteur'">
		    <!-- Même raisonnement que pour les ingrédients, cf plus bas -->
		    <xsl:if test="/objets/objet[@id=current()/@value]">
		      <td><a href="auteurs.html#{@value}"><xsl:value-of select="/objets/objet[@id=current()/@value]/info[@nom='idext']/@value"/></a></td>
		    </xsl:if>
		    <xsl:if test="not(/objets/objet[@id=current()/@value])">
		      <td><xsl:value-of select="@value"/></td>
		    </xsl:if>
		  </xsl:if>
		  <xsl:if test="@nom='ingrédient'">
		    <!--  On est obligé de tester l'existence de l'ingrédient dans la liste des ingrédients avant tout pour éviter de créer une case vide dans notre tableau -->
		    <xsl:if test="/objets/objet[@id=current()/@value]">
		      <!-- /objets/objet[@id=current()/@value] signifie qu'on cherche un noeud de type objet dont l'attribut id est égal à l'attribut value du noeud courant -->
		      <!--  Une fois ce noeud trouvé (s'il existe) on cherche parmi ses enfants les noeuds de type info avec l'attribut nom=nom et on affiche alors l'attribut value de cet enfant -->
		      <td><a href="ingredients.html#{@value}"><xsl:value-of select="/objets/objet[@id=current()/@value]/info[@nom='nom']/@value"/></a></td>
		    </xsl:if>
		    <!--  Si l'on n'a pas trouvé d'ingrédient correspondant à notre référence, alors on affiche simplement le nom mentionné dans la recette -->
		    <xsl:if test="not(/objets/objet[@id=current()/@value])">
		      <!--<xsl:if test="not(matches(@value, '.*\d.*'))">-->
		      <td><xsl:value-of select="@value"/></td>
		      <!--</xsl:if>-->
		    </xsl:if>
		  </xsl:if>
		  <xsl:if test="not(@nom='ingrédient') and not(@nom='auteur')">
		    <td><xsl:value-of select="@value"/></td>
		  </xsl:if>
		</tr>
	      </xsl:if>
	    </xsl:for-each>
	  </table>
	  <html>
	    <head>
	      <title>Recettes</title>
	    </head>
	    <body>
	      <xsl:call-template name="recettes_court"/>
	      <xsl:call-template name="recettes"/>
	    </body>
	  </html>
	</xsl:result-document>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>
  
  
  
  <!--Liste des ingrédients version courte-->
  <xsl:template name="ingredients_court">
    <h2>Index des ingrédients</h2>
    <ul>
      <xsl:for-each select="objets/objet">
	<xsl:if test="@type = 'ingredient'">
	  <li><a href="#{@id}">
	    <xsl:for-each select="info">
	      <xsl:if test="@nom = 'nom'">
		<xsl:value-of select="@value"/>
	      </xsl:if>
	    </xsl:for-each>
	  </a></li>
	</xsl:if>
      </xsl:for-each>
    </ul>
  </xsl:template>
  
  <!-- Liste détaillée des ingrédients -->
  <!-- Pour chaque ingrédient, son id sert d'ancre pour accéder au tableau lui correspondant  -->
  <xsl:template name="ingredients">
    <h2>Liste des ingrédients</h2>
    <xsl:for-each select="objets/objet">
      <xsl:if test="@type = 'ingredient'">
	<h3 id="{@id}">
	  <xsl:for-each select="info">
	    <xsl:if test="@nom='nom'">
	      <xsl:value-of select="@value"/>
	    </xsl:if>
	  </xsl:for-each>
	</h3>
	<table border="5">
	  <xsl:for-each select="info">
	    <xsl:if test="@nom='recette'">
	      <tr><td><xsl:value-of select="@nom"/></td>
	      <xsl:if test="/objets/objet[@id=current()/@value]">
		<td><a href="recettes.html#{@value}"><xsl:value-of select="/objets/objet[@id=current()/@value]/info[@nom='nom']/@value"/></a></td>
	      </xsl:if>
	      <xsl:if test="not(/objets/objet[@id=current()/@value])">
		<td><xsl:value-of select="@value"/></td>
	      </xsl:if>
	      </tr>
	    </xsl:if>

	    
	    <xsl:if test="not(@nom = 'nom') and not(@nom = 'recette')">
	      <tr>
		<td><xsl:value-of select="@nom"/></td>
		<td><xsl:value-of select="@value"/></td>
		<td> <xsl:text/>"<xsl:value-of select="."/>"<xsl:text/></td>
	      </tr>
	    </xsl:if>
	  </xsl:for-each>
	</table>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>
  
</xsl:stylesheet>

<!-- Liste des recettes-->
<!--<xsl:template match="objets" mode="recettes">
    <h2>Liste des recettes</h2>
    <ul>
    <xsl:for-each select="objet">
    <xsl:if test="@type = 'recette'">
    <xsl:for-each select="info">
    <xsl:if test="@nom = 'nom'">
    <li><xsl:value-of select="@value"/></li>
    </xsl:if>
    </xsl:for-each>
    </xsl:if>
    </xsl:for-each>
    </ul>
    </xsl:template>-->

<!-- Liste des auteurs -->
<!-- Pour chaque auteur, son indext sert d'ancre pour accéder au tableau lui correspondant  -->
<!-- Le tableau contient toutes les infos disponibles sauf son id (utilisécomme titre) et ses recettes (trop long)  -->
<!--<xsl:template match="objets" mode="auteurs">
    <h2>Liste des auteurs</h2>
    <xsl:for-each select="objet">
    <xsl:if test="@type = 'auteur'">
    <table border="5">
    <xsl:for-each select="info">
    <xsl:if test="@nom='idext'">
    <h3 id="{@value}"><xsl:value-of select="@value"/></h3>
    </xsl:if>
    <xsl:if test="not(@nom = 'idext') and not(@nom = 'recette')">
    <tr>
    <td><xsl:value-of select="@nom"/></td>
    <td><xsl:value-of select="@value"/></td>
    </tr>
    </xsl:if>
    </xsl:for-each>
    </table>
    </xsl:if>
    </xsl:for-each>
    </xsl:template>-->
