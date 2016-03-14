<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:fo="http://www.w3.org/1999/XSL/Format">
  <xsl:output name="default" method="html" version="4.0" encoding="iso-8859-1" indent="yes"/>

  <xsl:template name="categories">
    <xsl:for-each select="objets/objet">
      <xsl:if test="@type='catégorie'">
	<xsl:result-document href="html/category_{@id}.html" format="default">
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
	    <xsl:for-each select="info">
	      <xsl:if test="@nom='descriptif'">
		<p><xsl:text/>"<xsl:value-of select="."/>"<xsl:text/></p>
	      </xsl:if>
	    </xsl:for-each>
	    <xsl:call-template name="subcategories">
	      <xsl:with-param name="parent_id" select="@id"/>
	    </xsl:call-template>
	  </body>
	</html>
	</xsl:result-document>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>

  <xsl:template name="subcategories">
    <xsl:param name="parent_id"/>
    <h3>Liste des sous-catégories :</h3>
    <ul>
      <xsl:for-each select="/objets/objet">
	<xsl:if test="@type='sous-catégorie'">
	  <xsl:for-each select="info">
	    <xsl:if test="@nom = 'catégorie'">
	      <xsl:if test="@value = $parent_id">
		<li>
		  <b><xsl:value-of select="/objets/objet[@id=current()/../@id]/info[@nom='nom']/@value"/> :</b>
		  <xsl:text/>"<xsl:value-of select="/objets/objet[@id=current()/../@id]/info[@nom='descriptif']/."/>"<xsl:text/>
		</li>
	      </xsl:if>
	    </xsl:if>
	  </xsl:for-each>
	</xsl:if>
      </xsl:for-each>
    </ul>
  </xsl:template>
 
  </xsl:stylesheet>
