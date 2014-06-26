CREATE TABLE ${LABEL} (
  gi varchar(250) NOT NULL DEFAULT '',
  acc varchar(150) NOT NULL DEFAULT '',
  clone varchar(32) DEFAULT NULL,
  locus varchar(32) DEFAULT NULL,
  version tinyint(4) DEFAULT NULL,
  description text,
  seq text NOT NULL,
  PRIMARY KEY (gi),
  KEY cdna_accIND (acc),
  KEY probeINDclone (clone),
  KEY probeINDlocus (locus),
  FULLTEXT KEY probeFT_Desc (description)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

CREATE TABLE gseg_${LABEL}_good_pgs (
  uid int(10) unsigned NOT NULL AUTO_INCREMENT,
  gi varchar(250) DEFAULT NULL,
  gseg_gi varchar(255) DEFAULT NULL,
  E_O enum('+','-','?') NOT NULL DEFAULT '+',
  sim varchar(5) DEFAULT NULL,
  mlength varchar(5) DEFAULT NULL,
  cov varchar(5) DEFAULT NULL,
  chr int(10) NOT NULL DEFAULT '0',
  G_O enum('+','-','?') NOT NULL DEFAULT '+',
  l_pos int(10) unsigned NOT NULL DEFAULT '0',
  r_pos int(10) unsigned NOT NULL DEFAULT '0',
  pgs text NOT NULL,
  pgs_lpos int(10) unsigned NOT NULL DEFAULT '0',
  pgs_rpos int(10) unsigned NOT NULL DEFAULT '0',
  gseg_gaps blob NOT NULL,
  pgs_gaps blob NOT NULL,
  isCognate varchar(5) DEFAULT NULL,
  pairUID varchar(50) DEFAULT NULL,
  PRIMARY KEY (uid),
  KEY gpiC (chr),
  KEY giIND (gi),
  KEY pgpIND_rpos (r_pos),
  KEY pgpIND_lpos (l_pos)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

CREATE TABLE gseg_${LABEL}_good_pgs_exons (
  pgs_uid int(10) unsigned NOT NULL DEFAULT '0',
  num int(10) unsigned NOT NULL DEFAULT '0',
  pgs_start bigint(20) unsigned NOT NULL DEFAULT '0',
  pgs_stop bigint(20) unsigned NOT NULL DEFAULT '0',
  gseg_start bigint(20) unsigned NOT NULL DEFAULT '0',
  gseg_stop bigint(20) unsigned NOT NULL DEFAULT '0',
  score varchar(5) DEFAULT NULL,
  PRIMARY KEY (pgs_uid,num)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
