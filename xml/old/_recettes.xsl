<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:fo="http://www.w3.org/1999/XSL/Format">
  <xsl:include href="categories.xsl"/>
  <xsl:output name="default" method="html" version="4.0" encoding="iso-8859-1" indent="yes"/>
  
  <xsl:template match="/">
    <xsl:call-template name="homepage"/>
    <xsl:call-template name="recipes"/>
    <xsl:call-template name="authors"/>
    <xsl:call-template name="ingredients"/>
    <xsl:call-template name="categories"/>
  </xsl:template>

<!-- __________________________________________________________________ -->
  
  <xsl:template name="homepage">
    <xsl:result-document href="html/homepage.html" format="default">
      <html>
	<head>
	  <title>Odelices</title>
	</head>
	<body>
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
	  <xsl:call-template name="recipes_list"/>
	  <xsl:call-template name="ingredients_list"/>
	  <xsl:call-template name="authors_list"/>
	</body>
      </html>
    </xsl:result-document>
  </xsl:template>
  <xsl:template name="recipes_list">
    <h2>Index des recettes</h2>
    <ul>
      <xsl:for-each select="objets/objet">
	<xsl:if test="@type = 'recette'">
	  <li><a href="recipe_{@id}.html">
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
  <xsl:template name="authors_list">
    <h2>Index des auteurs</h2>
    <ul>
      <xsl:for-each select="objets/objet">
	<xsl:if test="@type = 'auteur'">
	  <xsl:for-each select="info">
	    <xsl:if test="@nom = 'idext'">
	      <li><a href="author_{../@id}.html"><xsl:value-of select="@value"/></a></li>
	    </xsl:if>
	  </xsl:for-each>
	</xsl:if>
      </xsl:for-each>
    </ul>
  </xsl:template>
  <xsl:template name="ingredients_list">
    <h2>Index des ingrédients</h2>
    <ul>
      <xsl:for-each select="objets/objet">
	<xsl:if test="@type = 'ingredient'">
	  <li><a href="ingredient_{@id}.html">
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

  <!-- __________________________________________________________________ -->

  <xsl:template name="recipes">
    <xsl:for-each select="objets/objet">
      <xsl:if test="@type = 'recette'">
	<xsl:result-document href="html/recipe_{@id}.html" format="default">
	  <html>
	    <xsl:for-each select="info">
	      <xsl:if test="@nom='nom'">
		<head><title><xsl:value-of select="@value"/></title></head>
	      </xsl:if>
	    </xsl:for-each>
	    <body>
	      <xsl:for-each select="info">
		<xsl:if test="@nom='nom'">
		  <h2><xsl:value-of select="@value"/></h2>
		</xsl:if>
	      </xsl:for-each>
	      <table border="5">
		<xsl:for-each select="info">
		  <xsl:if test="not(@nom = 'nom')">
		    <tr><td><xsl:value-of select="@nom"/></td>
		    <xsl:if test="@nom='auteur'">
		      <xsl:if test="/objets/objet[@id=current()/@value]">
			<td><a href="author_{@value}.html"><xsl:value-of select="/objets/objet[@id=current()/@value]/info[@nom='idext']/@value"/></a></td>
		      </xsl:if>
		      <xsl:if test="not(/objets/objet[@id=current()/@value])">
			<td><xsl:value-of select="@value"/></td>
		      </xsl:if>
		    </xsl:if>    
		    <xsl:if test="@nom='ingrédient'">
		      <xsl:if test="/objets/objet[@id=current()/@value]">
			<td><a href="ingredient_{@value}.html"><xsl:value-of select="/objets/objet[@id=current()/@value]/info[@nom='nom']/@value"/></a></td>
		      </xsl:if>
		      <xsl:if test="not(/objets/objet[@id=current()/@value])">
			<td><xsl:value-of select="@value"/></td>
		      </xsl:if>
		    </xsl:if>
		    <xsl:if test="@nom='sous-catégorie'">
		      <xsl:if test="/objets/objet[@id=current()/@value]">
			<td><a href="category_{/objets/objet[@id=current()/@value]/info[@nom='catégorie']/@value}.html"><xsl:value-of select="/objets/objet[@id=current()/@value]/info[@nom='nom']/@value"/></a></td>
		      </xsl:if>
		    </xsl:if>
		    <xsl:if test="not(@nom='ingrédient') and not(@nom='auteur') and not(@nom='sous-catégorie')">
		      <td><xsl:value-of select="@value"/></td>
		      <td><xsl:text/>"<xsl:value-of select="."/>"<xsl:text/></td>
		    </xsl:if>
		    </tr>
		  </xsl:if>
		</xsl:for-each>
	      </table>   
	    </body>
	  </html>
	</xsl:result-document>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>

  <!-- __________________________________________________________________ -->

  <xsl:template name="authors">
    <xsl:for-each select="objets/objet">
      <xsl:if test="@type = 'auteur'">
	<xsl:result-document href="html/author_{@id}.html" format="default">
	  <html>
	    <xsl:for-each select="info">
	      <xsl:if test="@nom='idext'">
		<head><title><xsl:value-of select="@value"/></title></head>
	      </xsl:if>
	    </xsl:for-each>
	    <body>
	      <table border="5">
		<xsl:for-each select="info">
		  <xsl:if test="@nom='idext'">
		    <h2><xsl:value-of select="@value"/></h2>
		  </xsl:if>
		  <xsl:if test="@nom='recette'">
		    <xsl:if test="/objets/objet[@id=current()/@value]">
		      <tr>
			<td><xsl:value-of select="@nom"/></td>
			<td><a href="recipe_{@value}.html"><xsl:value-of select="/objets/objet[@id=current()/@value]/info[@nom='nom']/@value"/></a></td>
		      </tr>
		    </xsl:if>
		  </xsl:if>
		  <xsl:if test="not(@nom = 'idext') and not(@nom = 'recette')">
		    <tr>
		      <td><xsl:value-of select="@nom"/></td>
		      <td><xsl:value-of select="@value"/></td>
		      <td><xsl:text/>"<xsl:value-of select="."/>"<xsl:text/></td>
		    </tr>
		  </xsl:if>
		</xsl:for-each>
	      </table>
	    </body>
	  </html>
	</xsl:result-document>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>

  <!-- __________________________________________________________________ -->

  <xsl:template name="ingredients">
    <xsl:for-each select="objets/objet">
      <xsl:if test="@type='ingredient'">
	<xsl:result-document href="html/ingredient_{@id}.html" format="default">
	  <html>
	    <xsl:for-each select="info">
	      <xsl:if test="@nom='nom'">
		<head><title><xsl:value-of select="@value"/></title></head>
	      </xsl:if>
	    </xsl:for-each>
	    <body>
	      <table border="5">
		<xsl:for-each select="info">
		  <xsl:if test="@nom='nom'">
		    <h2><xsl:value-of select="@value"/></h2>
		  </xsl:if>
		  <xsl:if test="@nom='recette'">
		    <xsl:if test="/objets/objet[@id=current()/@value]">
		      <tr>
			<td><xsl:value-of select="@nom"/></td>
			<td><a href="recipe_{@value}.html"><xsl:value-of select="/objets/objet[@id=current()/@value]/info[@nom='nom']/@value"/></a></td>
		      </tr>
		    </xsl:if>
		  </xsl:if>
		  <xsl:if test="not(@nom = 'nom') and not(@nom = 'recette')">
		    <tr>
		      <td><xsl:value-of select="@nom"/></td>
		      <td><xsl:value-of select="@value"/></td>
		      <td><xsl:text/>"<xsl:value-of select="."/>"<xsl:text/></td>
		    </tr>
		  </xsl:if>
		</xsl:for-each>
	      </table>
	    </body>
	  </html>
	</xsl:result-document>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>
  
</xsl:stylesheet>
