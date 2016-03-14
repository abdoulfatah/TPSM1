<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:fo="http://www.w3.org/1999/XSL/Format">
  <xsl:output name="default" method="html" version="4.0" encoding="iso-8859-1" indent="yes"/>

  <xsl:template name="categories">
    <xsl:for-each select="//categorie">
      <xsl:result-document href="html/categorie_{@id}.html" format="default">
	<html>
	  <head>
	    <link rel="stylesheet" type="text/css" href="menu.css"/>
	    <title><xsl:value-of select="nom"/></title>
	  </head>
	  <body>
	    <xsl:call-template name="menu"/>
	    <h2><xsl:value-of select="nom"/></h2>
	    <table border="5">
	      <xsl:for-each select="./*[not(name() = 'nom') and not(name() = 'sous-categorie')]">
		<tr>
		  <xsl:call-template name="ligne"/>
		</tr>
	      </xsl:for-each>
	    </table>
	    <xsl:if test="sous-categorie">
	      <h3>Liste des sous-catégories :</h3>
	    </xsl:if>
	    <xsl:for-each select="./*[name() = 'sous-categorie']">
	      <xsl:call-template name="sous-categorie"/>
	    </xsl:for-each>
	  </body>
	</html>
      </xsl:result-document>
    </xsl:for-each>
  </xsl:template>

  <xsl:template name="sous-categorie">
    <xsl:param name="parent_id"/>
    <ul>
      <xsl:for-each select="*[not(name() = 'nom_categorie')]">
	<li>
	  <b><xsl:value-of select="name()"/> :</b>
	  <xsl:text/>"<xsl:value-of select="."/>"<xsl:text/>
	</li>
      </xsl:for-each>
    </ul>
  </xsl:template>
  
</xsl:stylesheet>
