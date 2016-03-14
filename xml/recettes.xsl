<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="3.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:fo="http://www.w3.org/1999/XSL/Format">
  <xsl:include href="categories.xsl"/>
  <xsl:include href="menu.xsl"/>
  <xsl:output name="default" method="html" version="4.0" encoding="iso-8859-1" indent="yes"/>
  
  <xsl:template match="/">
    <xsl:call-template name="accueil"/>
    <xsl:call-template name="recettes"/>
    <xsl:call-template name="auteurs"/>
    <xsl:call-template name="ingredients"/>
    <xsl:call-template name="categories"/>
  </xsl:template>

  <!-- ================================================================== -->

  <!-- _____________________Page d'accueil_______________________________ -->
  <xsl:template name="accueil">
    <xsl:result-document href="html/accueil.html" format="default">
      <html>
	<head>
	  <link rel="stylesheet" type="text/css" href="menu.css"/>
	  <title>Odelices</title>
	</head>
	<body>
	  <xsl:call-template name="menu"/>
	  <h1>Ôdélices : Recettes de cuisine faciles et originales</h1>
	  <xsl:call-template name="recettes_5_ing">
	    <xsl:with-param name="objets" select="//recette"/>
	    <xsl:with-param name="nom" select='"Recettes contenant 5 ingrédients"'/>
	  </xsl:call-template>
	  <xsl:call-template name="auteurs_diff_facile">
	    <xsl:with-param name="objets" select="//auteur"/>
	    <xsl:with-param name="nom" select='"Auteurs n&#x27;ayant publié que des recettes faciles"'/>
	  </xsl:call-template>
	</body>
      </html>
    </xsl:result-document>
  </xsl:template>

  <!--_____________Recettes contenant exactement 5 ingrédients___________ -->
  <xsl:template name="recettes_5_ing">
    <xsl:param name="objets"/>
    <xsl:param name="nom"/>
    <h3><xsl:value-of select="$nom"/></h3>
    <xsl:for-each select="$objets">
      <xsl:if test="count(./nom_ingredient) = 5">
	<p><xsl:value-of select="nom"/></p>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>

  <!-- ____________Auteurs n'ayant écrit que des recettes faciles_______ -->
  <xsl:template name="auteurs_diff_facile">
    <xsl:param name="objets"/>
    <xsl:param name="nom"/>
    <h3><xsl:value-of select="$nom"/></h3>
    <xsl:for-each select="$objets">
      <xsl:variable name="recettes" select="./nom_recette"/>
      <xsl:variable name="nom_aut" select="./idext"/>
      <xsl:if test="count(//recette[@id=$recettes][difficulte='Facile']) = count(//recette[@id=$recettes])">
	<p><xsl:value-of select="$nom_aut"/></p>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>

  <!-- _________________Pages des recettes et sous-recettes_____________ -->
  <xsl:template name="recettes">
    <xsl:for-each select="//recette">
      <xsl:result-document href="html/recette_{@id}.html" format="default">
	<html>
	  <head>
	    <link rel="stylesheet" type="text/css" href="menu.css"/>
	    <title><xsl:value-of select="nom"/></title>
	  </head>
	  <body>
	    <xsl:call-template name="menu"/>
	    <h2><xsl:value-of select="nom"/></h2>
	    <table border="5">
	      <xsl:for-each select="./*[not(name() = 'nom')]">
		<tr>
		  <xsl:call-template name="ligne"/>
		</tr>
	      </xsl:for-each>
	    </table>   
	  </body>
	</html>
      </xsl:result-document>
    </xsl:for-each>
  </xsl:template>

  <!-- ______________Pages des auteurs___________________________________ -->
  <xsl:template name="auteurs">
    <xsl:for-each select="//auteur">
      <xsl:result-document href="html/auteur_{@id}.html" format="default">
	<html>
	  <head>
	    <link rel="stylesheet" type="text/css" href="menu.css"/>
	    <title><xsl:value-of select="idext"/></title>
	  </head>
	  <body>
	    <xsl:call-template name="menu"/>
	    <h2><xsl:value-of select="idext"/></h2>
	    <table border="5">
	      <xsl:for-each select="./*[not(name() = idext)]">
		<tr>
		  <xsl:call-template name="ligne"/>
		</tr>
	      </xsl:for-each>
	    </table>   
	  </body>
	</html>
      </xsl:result-document>
    </xsl:for-each>
  </xsl:template>

  <!-- _________________Page des ingrédients_____________________________ -->
  <xsl:template name="ingredients">
    <xsl:for-each select="//ingredient">
      <xsl:result-document href="html/ingredient_{@id}.html" format="default">
	<html>
	  <head>
	    <link rel="stylesheet" type="text/css" href="menu.css"/>
	    <title><xsl:value-of select="nom"/></title>
	  </head>
	  <body>
	    <xsl:call-template name="menu"/>
	    <h2><xsl:value-of select="nom"/></h2>
	    <table border="5">
	      <xsl:for-each select="./*[not(name() = 'nom')]">
		<tr>
		  <xsl:call-template name="ligne"/>
		</tr>
	      </xsl:for-each>
	    </table>   
	  </body>
	</html>
      </xsl:result-document>
    </xsl:for-each>
  </xsl:template>

  <!-- Template général pour l'affichage d'une ligne de tableau_________ -->
  <xsl:template name="ligne">
    <td><xsl:value-of select="name()"/></td>
    <xsl:choose>
      <xsl:when test="name() = 'nom_ingredient'">
	<td><xsl:call-template name="reference"/></td>
      </xsl:when>
      <xsl:when test="name() = 'nom_auteur'">
	<td><xsl:call-template name="reference"/></td>
      </xsl:when>
      <xsl:when test="name() = 'nom_recette'">
	<td><xsl:call-template name="reference"/></td>
      </xsl:when>
      <xsl:when test="name() = 'nom_categorie'">
	<td><xsl:call-template name="reference"/></td>
      </xsl:when>
      <xsl:when test="name() = 'nom_sous-categorie'">
	<td><xsl:call-template name="reference"/></td>
      </xsl:when>
      <xsl:otherwise>
	<td><xsl:value-of select="."/></td>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Template général pour la recherche des références (e.g. nom_auteur)-->
  <xsl:template name="reference">
    <xsl:variable name="ref" select="."/>
    <xsl:choose>
      <xsl:when test="//*[@id=$ref]">
	<xsl:for-each select="//*[@id=$ref]">
	  <xsl:choose>
	    <xsl:when test="./idext">
	      <a href="auteur_{$ref}.html"><xsl:value-of select="./idext"/></a>
	    </xsl:when>
	    <xsl:when test="name() = 'sous-categorie'">
	      <a href="categorie_{../@id}.html"><xsl:value-of select="./nom"/></a>
	    </xsl:when>
	    <xsl:otherwise>
	      <a href="{name()}_{$ref}.html"><xsl:value-of select="./nom"/></a>
	    </xsl:otherwise>
	  </xsl:choose>
	</xsl:for-each>
      </xsl:when>
      <xsl:otherwise>
	<xsl:value-of select="."/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>


</xsl:stylesheet>
