CREATE TABLE ${LABEL} (
  gi varchar(32) NOT NULL DEFAULT '',
  acc varchar(32) NOT NULL DEFAULT '',
  clone varchar(32) DEFAULT NULL,
  locus varchar(32) DEFAULT NULL,
  version tinyint(4) NOT NULL DEFAULT '0',
  description text,
  seq text NOT NULL,
  type enum('F','T','U') DEFAULT 'U',
  PRIMARY KEY (gi),
  KEY ${LABEL}_accIND (acc),
  KEY ${LABEL}INDclone (clone),
  KEY ${LABEL}INDlocus (locus),
  FULLTEXT KEY ${LABEL}FTdesc (description)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
CREATE TABLE gseg_${LABEL}_good_pgs (
  uid int(10) unsigned NOT NULL AUTO_INCREMENT,
  gi varchar(32) NOT NULL DEFAULT '',
  E_O enum('+','-','?') NOT NULL DEFAULT '+',
  sim float NOT NULL DEFAULT '0',
  mlength int(10) unsigned NOT NULL DEFAULT '0',
  cov float NOT NULL DEFAULT '0',
  gseg_gi varchar(32) NOT NULL DEFAULT '',
  G_O enum('+','-','?') NOT NULL DEFAULT '+',
  l_pos int(10) unsigned NOT NULL DEFAULT '0',
  r_pos int(10) unsigned NOT NULL DEFAULT '0',
  pgs text NOT NULL,
  pgs_lpos int(10) unsigned NOT NULL DEFAULT '0',
  pgs_rpos int(10) unsigned NOT NULL DEFAULT '0',
  gseg_gaps blob NOT NULL,
  pgs_gaps blob NOT NULL,
  isCognate enum('True','False') NOT NULL DEFAULT 'True',
  pairUID varchar(50) NOT NULL DEFAULT '',
  mergeNOTE text,
  PRIMARY KEY (uid),
  KEY gpiC (gseg_gi),
  KEY giIND (gi),
  KEY gegpINDlpos (l_pos),
  KEY gegpINDrpos (r_pos)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
CREATE TABLE gseg_${LABEL}_good_pgs_exons (
  pgs_uid int(10) unsigned NOT NULL DEFAULT '0',
  num int(10) unsigned NOT NULL DEFAULT '0',
  gseg_start bigint(20) unsigned NOT NULL DEFAULT '0',
  gseg_stop bigint(20) unsigned NOT NULL DEFAULT '0',
  pgs_start bigint(20) unsigned NOT NULL DEFAULT '0',
  pgs_stop bigint(20) unsigned NOT NULL DEFAULT '0',
  score float NOT NULL DEFAULT '0',
  KEY gegpeINDpn (pgs_uid,num)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
CREATE TABLE gseg_${LABEL}_good_pgs_introns (
  pgs_uid int(10) unsigned NOT NULL DEFAULT '0',
  num int(10) unsigned NOT NULL DEFAULT '0',
  gseg_start bigint(20) unsigned NOT NULL DEFAULT '0',
  gseg_stop bigint(20) unsigned NOT NULL DEFAULT '0',
  Dscore float NOT NULL DEFAULT '0',
  Dsim float NOT NULL DEFAULT '-1',
  Ascore float NOT NULL DEFAULT '0',
  Asim float NOT NULL DEFAULT '-1',
  PRIMARY KEY (pgs_uid,num)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
