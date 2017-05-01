--
-- PostgreSQL database dump
--
-- Dumped from database version 9.4.10
-- Dumped by pg_dump version 9.4.0
-- Started on 2017-05-01 10:55:12

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- TOC entry 7 (class 2615 OID 16387)
-- Name: panther_upl; Type: SCHEMA; Schema: -; Owner: panther_upl
--

CREATE SCHEMA panther_upl;


ALTER SCHEMA panther_upl OWNER TO panther_upl;

SET search_path = panther_upl, pg_catalog;

--
-- TOC entry 749 (class 1255 OID 702352377)
-- Name: step001_000_load_release_parameters(integer, integer, text); Type: FUNCTION; Schema: panther_upl; Owner: postgres
--

CREATE FUNCTION step001_000_load_release_parameters(cls_version_sid integer, cls_type_sid integer, version text) RETURNS void
    LANGUAGE sql
    AS $$
/*
   STEP 1.0
   This is the first Function called to begin the transfer of a New Release from Curation panther_upl to panther schema.
   The Curation panther schema replaces the Oracle Test Tsipthr database. After the testing of the new release is done using the
   Curation panther schema, this schema will be backed-up and then restored as the database needed for the Production DB for the new release.
   At the time of pushing the new release (restoring to a DB with the name of the new release), we will also need to shut down the Production web site
   and also back-up the panther_share schema from the current Production database to obtain a copy of all the users and their lists. If any ID mapping is needed
   to be done between releases, it should be done after the panther_share schema is restored into the New Release DB just prior to releasing the New Version into production.
   ---JTC 02/18/2016
*/   
    INSERT INTO panther.CLASSIFICATION_VERSION 
(CLASSIFICATION_VERSION_SID,  CLASSIFICATION_TYPE_SID,  VERSION, CREATION_DATE,  RELEASE_DATE)
VALUES ( cls_version_sid, cls_type_sid, version, now(), NULL);
$$;


ALTER FUNCTION panther_upl.step001_000_load_release_parameters(cls_version_sid integer, cls_type_sid integer, version text) OWNER TO postgres;

--
-- TOC entry 735 (class 1255 OID 702352453)
-- Name: step002_000_load_classification(integer); Type: FUNCTION; Schema: panther_upl; Owner: postgres
--

CREATE FUNCTION step002_000_load_classification(cls_version_sid integer) RETURNS void
    LANGUAGE sql
    AS $$
/*
   STEP 2.0
   This is Function called to transfer the Curation panther_upl.classification rows for the new release to Curation panther.classification table.
   In the panther schema there is a Sequence called panther_uids which will be used to generate unique IDs for all rows added to the tables in the
   panther schema. Since, all tables were truncated prior to loading we have started this sequence at 1 with an increment of 1.
   ---
   ---JTC 02/18/2016
*/   
    INSERT INTO panther.classification 
(classification_id, classification_version_sid, depth, name, accession, definition, created_by, creation_date ) 
SELECT nextval('panther.panther_uids'),cls_version_sid,c.depth,c.name,c.accession,c.definition,c.created_by,c.creation_date 
FROM panther_upl.classification c
 WHERE 
  c.classification_version_sid = cls_version_sid         
  and c.obsolescence_date is null; 
$$;


ALTER FUNCTION panther_upl.step002_000_load_classification(cls_version_sid integer) OWNER TO postgres;

--
-- TOC entry 750 (class 1255 OID 702443996)
-- Name: step002_001_load_classification_with_pthr00000(integer); Type: FUNCTION; Schema: panther_upl; Owner: postgres
--

CREATE FUNCTION step002_001_load_classification_with_pthr00000(cls_version_sid integer) RETURNS void
    LANGUAGE sql
    AS $$
/*
   STEP 2.001
   This is Function called to insert a row into the Curation panther_upl.classification for the PTHR00000 family.
   ---
   ---JTC 02/18/2016
*/   
    INSERT INTO panther.classification 
(classification_id, classification_version_sid, depth, name, accession, created_by, creation_date ) 
values (nextval('panther.panther_uids'),cls_version_sid,5,'NO FAMILY ASSIGNMENT','PTHR00000',1,now() ); 
$$;


ALTER FUNCTION panther_upl.step002_001_load_classification_with_pthr00000(cls_version_sid integer) OWNER TO postgres;

--
-- TOC entry 751 (class 1255 OID 702563070)
-- Name: step002_002_load_classification_with_goslim(integer); Type: FUNCTION; Schema: panther_upl; Owner: postgres
--

CREATE FUNCTION step002_002_load_classification_with_goslim(cls_version_sid integer) RETURNS void
    LANGUAGE sql
    AS $$
/*
   STEP 2.3
   This is Function called to insert the GOSlim rows into Curation panther_upl.classification table. The parameter
    used for cls_version_sid = 81 for the GOSLim and we had to use the query below because this classification_version_sid
    is not present in the Curation panther_up.classification table. It has hard coded parameters of 303 for latest GO and uses
    relationship_type _sids of 400 to 499 from the relationship_type table to get all GOSlim entries needed to insert in classification table
    The root terms are in the GOSLIM and relationship, so the query just retrieves all the child terms from the relationship table.
    There are a total 551 terms. The rrot terms will be inserted separately.
   ---
   ---HM, 3/16/2016
*/   
    INSERT INTO panther.classification 
(classification_id, classification_version_sid, depth, name, accession, definition, created_by, creation_date, term_type_sid ) 
SELECT  nextval('panther.panther_uids'), cls_version_sid, x.depth, x.name, x.accession, x.definition, x.created_by, x.creation_date, x.term_type_sid
from
(SELECT  distinct c2.depth,c2.name,c2.accession,c2.definition,c2.created_by,c2.creation_date, c2.term_type_sid  from 
panther_upl.classification c1, panther_upl.classification_relationship r, panther_upl.classification c2
where 
c1.classification_version_sid = 303 and
c2.classification_version_sid = 303 and
c1.classification_id = r.parent_classification_id and
c2.classification_id = r.child_classification_id and  
r.relationship_type_sid > 399 and r.relationship_type_sid < 501 and 
c1.obsolescence_date is null and c2.obsolescence_date is null  and r.obsolescence_date is null) x ; 
$$;


ALTER FUNCTION panther_upl.step002_002_load_classification_with_goslim(cls_version_sid integer) OWNER TO postgres;

--
-- TOC entry 752 (class 1255 OID 713218279)
-- Name: step002_003_load_classification_with_goslim_root(integer); Type: FUNCTION; Schema: panther_upl; Owner: postgres
--

CREATE FUNCTION step002_003_load_classification_with_goslim_root(cls_version_sid integer) RETURNS void
    LANGUAGE sql
    AS $$
/*
   STEP 2.3
   This is Function is to load the root GO terms (GO:0003674, GO:0005575, GO:0008150).
   ---
   ---HM, 3/16/2016
*/   
    INSERT INTO panther.classification 
(classification_id, classification_version_sid, depth, name, accession, definition, created_by, creation_date, term_type_sid ) 
SELECT  nextval('panther.panther_uids'), cls_version_sid, 0, name, accession, definition, created_by, creation_date, term_type_sid
from panther_upl.classification
where classification_version_sid = 303
and accession in ('GO:0003674', 'GO:0005575', 'GO:0008150'); ; 
$$;


ALTER FUNCTION panther_upl.step002_003_load_classification_with_goslim_root(cls_version_sid integer) OWNER TO postgres;

--
-- TOC entry 737 (class 1255 OID 713218283)
-- Name: step002_004_load_classification_with_protein_class(integer); Type: FUNCTION; Schema: panther_upl; Owner: postgres
--

CREATE FUNCTION step002_004_load_classification_with_protein_class(cls_version_sid integer) RETURNS void
    LANGUAGE sql
    AS $$
/*
   STEP 2.4
   This is Function is to load the protein class terms from panther_upl to panther.
   However, need to set the depth to 0 to the root term (PC00000). Did it on the sql editor window, with the following query

   update panther.classification
   set depth = 0
   where classification_version_sid = 81
   and accession = 'PC00000';
   ---
   ---HM, 3/16/2016
*/   
    INSERT INTO panther.classification 
(classification_id, classification_version_sid, depth, name, accession, definition, created_by, creation_date, term_type_sid ) 
SELECT  nextval('panther.panther_uids'), cls_version_sid, depth, name, accession, definition, created_by, creation_date, 15  
from panther_upl.classification
where classification_version_sid = 400
and obsolescence_date is null; 
$$;


ALTER FUNCTION panther_upl.step002_004_load_classification_with_protein_class(cls_version_sid integer) OWNER TO postgres;

--
-- TOC entry 753 (class 1255 OID 702443999)
-- Name: step003_000_load_classification_relationship(integer); Type: FUNCTION; Schema: panther_upl; Owner: postgres
--

CREATE FUNCTION step003_000_load_classification_relationship(cls_version_sid integer) RETURNS void
    LANGUAGE sql
    AS $$
/*
   STEP 3.00
   This is Function called to insert the rows into the Curation panther.classification_reelationship table. It maps the new classification_ids 
   in the panther.classification table for the paren_classification_id and Child_classification columns in the table. It also makes sure it does not copy any
   obsoleted rows for the new release.
   ---
   ---JTC 02/18/2016
*/   
    INSERT INTO panther.classification_relationship 
(classification_relationship_id,parent_classification_id,child_classification_id,relationship_type_sid,rank,created_by,creation_date) 
SELECT  nextval('panther.panther_uids'), c3.classification_id, c4.classification_id, r.relationship_type_sid, r.rank, r.created_by, r.creation_date from 
panther_upl.classification c1, panther.classification c3, panther_upl.classification_relationship r, panther_upl.classification c2, panther.classification c4
where 
c1.accession = c3.accession and
c1.classification_version_sid = cls_version_sid and
c3.classification_version_sid = cls_version_sid and
c1.classification_id = r.parent_classification_id and
c2.classification_id = r.child_classification_id and
c2.accession = c4.accession and c4.classification_version_sid = cls_version_sid and 
c1.obsolescence_date is null and c2.obsolescence_date is null and c3.obsolescence_date is null and c4.obsolescence_date is null and r.obsolescence_date is null ; 
$$;


ALTER FUNCTION panther_upl.step003_000_load_classification_relationship(cls_version_sid integer) OWNER TO postgres;

--
-- TOC entry 736 (class 1255 OID 702563071)
-- Name: step003_001_load_classification_relationship_with_goslim(integer); Type: FUNCTION; Schema: panther_upl; Owner: postgres
--

CREATE FUNCTION step003_001_load_classification_relationship_with_goslim(cls_version_sid integer) RETURNS void
    LANGUAGE sql
    AS $$
/*
   STEP 3.001
   This is Function called to insert the rows for GOSlim Ontology =81 into the Curation panther.classification_relationship table. It maps the new classification_ids 
   in the panther.classification table for the paren_classification_id and Child_classification columns in the table. It also makes sure it does not copy any
   obsoleted rows for the new release. It uses the parameter for Ontology version 81 and uses hard-coded values of 303 for GOSlim classification_version_sid.
   Al total of 655 rows were inserted.
   ---
   ---HM, 3/16/2016
*/   
    INSERT INTO panther.classification_relationship 
(classification_relationship_id,parent_classification_id,child_classification_id,relationship_type_sid,rank,created_by,creation_date) 
SELECT  nextval('panther.panther_uids'), c3.classification_id, c4.classification_id, r.relationship_type_sid, r.rank, r.created_by, r.creation_date 
from 
panther_upl.classification c1, panther.classification c3, panther_upl.classification_relationship r, panther_upl.classification c2, panther.classification c4
where 
c1.accession = c3.accession 
and c1.classification_version_sid = 303 
and c3.classification_version_sid = 81
and c1.classification_id = r.parent_classification_id 
and c2.classification_version_sid = 303 
and c2.classification_id = r.child_classification_id 
and c2.accession = c4.accession 
and c4.classification_version_sid = 81 
and c1.obsolescence_date is null 
and c2.obsolescence_date is null 
and c3.obsolescence_date is null 
and c4.obsolescence_date is null 
and r.obsolescence_date is null 
and  r.relationship_type_sid > 399 and r.relationship_type_sid < 500; 
$$;


ALTER FUNCTION panther_upl.step003_001_load_classification_relationship_with_goslim(cls_version_sid integer) OWNER TO postgres;

--
-- TOC entry 738 (class 1255 OID 713219188)
-- Name: step003_002_load_classification_relationship_with_protein_class(integer); Type: FUNCTION; Schema: panther_upl; Owner: postgres
--

CREATE FUNCTION step003_002_load_classification_relationship_with_protein_class(cls_version_sid integer) RETURNS void
    LANGUAGE sql
    AS $$
/*
   STEP 3.001
   This is Function called to insert the rows for protein class into the Curation panther.classification_relationship table. It maps the new classification_ids 
   in the panther.classification table for the paren_classification_id and Child_classification columns in the table. It also makes sure it does not copy any
   obsoleted rows for the new release. It uses the parameter for Ontology version 81 and uses hard-coded values of 400 for protein class classification_version_sid.
   Al total of 264 rows were inserted.
   ---
   ---HM, 3/16/2016
*/   
    INSERT INTO panther.classification_relationship 
(classification_relationship_id,parent_classification_id,child_classification_id,relationship_type_sid,rank,created_by,creation_date) 
SELECT  nextval('panther.panther_uids'), c3.classification_id, c4.classification_id, r.relationship_type_sid, r.rank, r.created_by, r.creation_date 
from 
panther_upl.classification c1, panther.classification c3, panther_upl.classification_relationship r, panther_upl.classification c2, panther.classification c4
where 
c1.accession = c3.accession 
and c1.classification_version_sid = 400 
and c3.classification_version_sid = 81
and c1.classification_id = r.parent_classification_id 
and c2.classification_version_sid = 400
and c2.classification_id = r.child_classification_id 
and c2.accession = c4.accession 
and c4.classification_version_sid = 81 
and c1.obsolescence_date is null 
and c2.obsolescence_date is null 
and c3.obsolescence_date is null 
and c4.obsolescence_date is null 
and r.obsolescence_date is null 
; 
$$;


ALTER FUNCTION panther_upl.step003_002_load_classification_relationship_with_protein_class(cls_version_sid integer) OWNER TO postgres;

--
-- TOC entry 728 (class 1255 OID 702594921)
-- Name: step004_000_load_organism(integer); Type: FUNCTION; Schema: panther_upl; Owner: postgres
--

CREATE FUNCTION step004_000_load_organism(cls_version_sid integer) RETURNS void
    LANGUAGE sql
    AS $$
/*
   STEP 4.0
   This is Function called to insert the rows for the Organism Table 
   ---
   ---JTC 02/22/2016
*/   
    INSERT INTO panther.organism 
(organism_id, organism, conversion, short_name, name, common_name, logical_ordering, ref_genome, classification_version_sid, taxon_id) 
SELECT  organism_id, organism, conversion , short_name, name, common_name, logical_ordering, ref_genome, classification_version_sid, taxon_id
 from panther_upl.organism where classification_version_sid = cls_version_sid; 
$$;


ALTER FUNCTION panther_upl.step004_000_load_organism(cls_version_sid integer) OWNER TO postgres;

--
-- TOC entry 754 (class 1255 OID 725457165)
-- Name: step005_000_load_gene(integer); Type: FUNCTION; Schema: panther_upl; Owner: postgres
--

CREATE FUNCTION step005_000_load_gene(cls_version_sid integer) RETURNS void
    LANGUAGE sql
    AS $$
/*
   This function is to copy the gene tabel data from the curation database (panther_upl schema) to the testing database (panther schema).
   
*/   
    INSERT INTO panther.gene 
(gene_id, primary_ext_id, primary_ext_acc, gene_name, gene_symbol, created_by, creation_date, classification_version_sid, ext_db_gene_id) 
SELECT nextval('panther.panther_uids'),primary_ext_acc, primary_ext_acc, gene_name, gene_symbol, created_by, creation_date, classification_version_sid, ext_db_gene_id
FROM panther_upl.gene g
WHERE g.classification_version_sid = cls_version_sid         
  and g.obsolescence_date is null; 
$$;


ALTER FUNCTION panther_upl.step005_000_load_gene(cls_version_sid integer) OWNER TO postgres;

--
-- TOC entry 798 (class 1255 OID 727177031)
-- Name: step006_000_load_transcript(integer); Type: FUNCTION; Schema: panther_upl; Owner: postgres
--

CREATE FUNCTION step006_000_load_transcript(cls_version_sid integer) RETURNS void
    LANGUAGE sql
    AS $$
/*
   This function is to copy the gene tabel data from the curation database (panther_upl schema) to the testing database (panther schema).
   
*/   
    INSERT INTO panther.transcript 
(transcript_id, gene_id, primary_ext_id, primary_ext_acc, created_by, creation_date, classification_version_sid) 
SELECT nextval('panther.panther_uids'),g2.gene_id, p.primary_ext_id, p.primary_ext_acc, g.created_by, g.creation_date, g.classification_version_sid
from panther_upl.gene g, panther_upl.protein p, panther_upl.gene_protein gp, panther.gene g2
where g.classification_version_sid = cls_version_sid
and g.obsolescence_date is null
and g.primary_ext_acc = g2.primary_ext_acc
and g2.obsolescence_date is null
and g.gene_id = gp.gene_id
and gp.obsolescence_date is null
and gp.protein_id = p.protein_id
and p.obsolescence_date is null;
$$;


ALTER FUNCTION panther_upl.step006_000_load_transcript(cls_version_sid integer) OWNER TO postgres;

--
-- TOC entry 744 (class 1255 OID 729521864)
-- Name: step007_000_load_protein(integer); Type: FUNCTION; Schema: panther_upl; Owner: postgres
--

CREATE FUNCTION step007_000_load_protein(cls_version_sid integer) RETURNS void
    LANGUAGE sql
    AS $$
/*
   This function is to copy the protein tabel data from the curation database (panther_upl schema) to the testing database (panther schema).
   
*/   
    INSERT INTO panther.protein 
(protein_id, primary_ext_id, primary_ext_acc, created_by, creation_date, classification_version_sid) 
SELECT nextval('panther.panther_uids'),primary_ext_id, primary_ext_acc, created_by, creation_date, classification_version_sid
from panther_upl.protein
where classification_version_sid = cls_version_sid
and obsolescence_date is null;
$$;


ALTER FUNCTION panther_upl.step007_000_load_protein(cls_version_sid integer) OWNER TO postgres;

--
-- TOC entry 745 (class 1255 OID 744793653)
-- Name: step007_001_update_protein(integer); Type: FUNCTION; Schema: panther_upl; Owner: postgres
--

CREATE FUNCTION step007_001_update_protein(cls_version_sid integer) RETURNS void
    LANGUAGE sql
    AS $$
/*
   This function is to update the protein table with the transcripts and is_trainingset columns. Not all rows in the protein table need to be udpated.
   
*/   
update panther.protein p
set transcript_id = t.transcript_id, is_trainingset = 1
from panther.transcript t
where p.classification_version_sid = cls_version_sid
and p.obsolescence_date is null
and p.primary_ext_id = t.primary_ext_id
and t.obsolescence_date is null
and t.classification_version_sid = cls_version_sid;
$$;


ALTER FUNCTION panther_upl.step007_001_update_protein(cls_version_sid integer) OWNER TO postgres;

--
-- TOC entry 767 (class 1255 OID 744794009)
-- Name: step008_000_update_sequence_source(integer); Type: FUNCTION; Schema: panther_upl; Owner: postgres
--

CREATE FUNCTION step008_000_update_sequence_source(cls_version_sid integer) RETURNS void
    LANGUAGE sql
    AS $$
/*
   This function is to update the sequence source table.
   
*/   
insert into panther.sequence_source
(source_id, name, organism_id, database, created_by, creation_date)
select nextval('panther.panther_uids'), s.name, o2.organism_id, s.database, s.created_by, s.creation_date
from panther_upl.protein_source s, panther_upl.organism o, panther.organism o2
where s.creation_date > '2017-01-01'
and s.obsolescence_date is null
and s.organism_id = o.organism_id
and o.organism = o2.organism
;
$$;


ALTER FUNCTION panther_upl.step008_000_update_sequence_source(cls_version_sid integer) OWNER TO postgres;

--
-- TOC entry 746 (class 1255 OID 744794224)
-- Name: step009_001_update_primary_object_protein(integer); Type: FUNCTION; Schema: panther_upl; Owner: postgres
--

CREATE FUNCTION step009_001_update_primary_object_protein(cls_version_sid integer) RETURNS void
    LANGUAGE sql
    AS $$
/*
   This function is to update the protein data in the primary object table.
   
*/   
insert into panther.primary_object
(primary_object_id, source_id)
select p2.protein_id, s2.source_id 
from panther_upl.protein p1, panther.protein p2, panther_upl.protein_source s1, panther.sequence_source s2, panther_upl.organism o1, panther.organism o2
where p1.classification_version_sid = cls_version_sid
and p1.obsolescence_date is null
and p1.primary_ext_id = p2.primary_ext_id
and p2.classification_version_sid = cls_version_sid
and p2.obsolescence_date is null
and p1.source_id = s1.source_id
and s1.organism_id = o1.organism_id
and o2.organism=o1.organism
and o2.organism_id = s2.organism_id
;
$$;


ALTER FUNCTION panther_upl.step009_001_update_primary_object_protein(cls_version_sid integer) OWNER TO postgres;

--
-- TOC entry 768 (class 1255 OID 746195424)
-- Name: step009_002_update_primary_object_transcript(integer); Type: FUNCTION; Schema: panther_upl; Owner: postgres
--

CREATE FUNCTION step009_002_update_primary_object_transcript(cls_version_sid integer) RETURNS void
    LANGUAGE sql
    AS $$
/*
   This function is to update the transcript data in the primary object table.
   
*/   
insert into panther.primary_object
(primary_object_id, source_id)
select t.transcript_id, s2.source_id 
from panther_upl.protein p1, panther.protein p2, panther_upl.protein_source s1, panther.sequence_source s2, panther_upl.organism o1, panther.organism o2, panther.transcript t
where p1.classification_version_sid = cls_version_sid
and p1.obsolescence_date is null
and p1.primary_ext_id = p2.primary_ext_id
and p2.classification_version_sid = cls_version_sid
and p2.obsolescence_date is null
and p1.source_id = s1.source_id
and s1.organism_id = o1.organism_id
and o2.organism=o1.organism
and o2.organism_id = s2.organism_id
and p2.transcript_id = t.transcript_id
;
$$;


ALTER FUNCTION panther_upl.step009_002_update_primary_object_transcript(cls_version_sid integer) OWNER TO postgres;

--
-- TOC entry 755 (class 1255 OID 747242423)
-- Name: step009_003_update_primary_object_gene(integer); Type: FUNCTION; Schema: panther_upl; Owner: postgres
--

CREATE FUNCTION step009_003_update_primary_object_gene(cls_version_sid integer) RETURNS void
    LANGUAGE sql
    AS $$
/*
   This function is to update the gene data in the primary object table.
   
*/   
insert into panther.primary_object
(primary_object_id, source_id)
select g2.gene_id, s2.source_id 
from panther_upl.protein p1, panther.protein p2, panther_upl.protein_source s1, panther.sequence_source s2, panther_upl.organism o1, panther.organism o2, panther_upl.gene_protein gp, panther_upl.gene g1, panther.gene g2
where p1.classification_version_sid = cls_version_sid
and p1.obsolescence_date is null
and p1.protein_id = gp.protein_id
and gp.obsolescence_date is null
and gp.gene_id = g1.gene_id
and g1.obsolescence_date is null
and g1.primary_ext_acc = g2.primary_ext_acc
and g1.classification_version_sid = cls_version_sid
and g2.classification_version_sid = cls_version_sid
and p1.primary_ext_id = p2.primary_ext_id
and p2.classification_version_sid = cls_version_sid
and p2.obsolescence_date is null
and p1.source_id = s1.source_id
and s1.organism_id = o1.organism_id
and o1.organism=o2.organism
and o2.organism_id = s2.organism_id
;
$$;


ALTER FUNCTION panther_upl.step009_003_update_primary_object_gene(cls_version_sid integer) OWNER TO postgres;

--
-- TOC entry 756 (class 1255 OID 752968993)
-- Name: step010_000_update_tree_detail(integer); Type: FUNCTION; Schema: panther_upl; Owner: postgres
--

CREATE FUNCTION step010_000_update_tree_detail(cls_version_sid integer) RETURNS void
    LANGUAGE sql
    AS $$
/*
   This function is to update the tree detail table.
   
*/   
insert into panther.tree_detail
(tree_id, classification_id, created_by, creation_date, tree_text)
select nextval('panther.panther_uids'), c.classification_id, t.created_by, t.creation_date, t.tree_text 
from panther_upl.tree_detail t, panther_upl.classification c1, panther.classification c
where c1.classification_version_sid = cls_version_sid
and c1.obsolescence_date is null
and c1.classification_id = t.classification_id
and c1.accession = c.accession
;
$$;


ALTER FUNCTION panther_upl.step010_000_update_tree_detail(cls_version_sid integer) OWNER TO postgres;

--
-- TOC entry 757 (class 1255 OID 763932800)
-- Name: step011_000_update_node(integer); Type: FUNCTION; Schema: panther_upl; Owner: postgres
--

CREATE FUNCTION step011_000_update_node(cls_version_sid integer) RETURNS void
    LANGUAGE sql
    AS $$
/*
   This function is to update the node table.
   Please note that the node_type_id and event_type_id are the same between the two schemas, the ids are just copied over. 
   Otherwise, they should be mapped through the node_type and event_type tables.
   
*/   
insert into panther.node
(node_id, accession, public_id, classification_version_sid, node_type_id, event_type_id, branch_length, created_by, creation_date)
select nextval('panther.panther_uids'), n.accession, n.public_id, n.classification_version_sid, n.node_type_id, n.event_type_id, n.branch_length, n.created_by, n.creation_date  
from panther_upl.node n
where classification_version_sid = cls_version_sid
and obsolescence_date is null;
;
$$;


ALTER FUNCTION panther_upl.step011_000_update_node(cls_version_sid integer) OWNER TO postgres;

--
-- TOC entry 758 (class 1255 OID 769405480)
-- Name: step012_000_update_gene_node(integer); Type: FUNCTION; Schema: panther_upl; Owner: postgres
--

CREATE FUNCTION step012_000_update_gene_node(cls_version_sid integer) RETURNS void
    LANGUAGE sql
    AS $$
/*
   This function is to update the gene_node table.

   
*/   
insert into panther.gene_node
(gene_node_id, gene_id, node_id, created_by, creation_date)
select nextval('panther.panther_uids'), g1.gene_id, n1.node_id, gn.created_by, gn.creation_date 
from panther_upl.gene_node gn, panther_upl.gene g, panther_upl.node n, panther.gene g1, panther.node n1
where g.classification_version_sid = cls_version_sid
and g.obsolescence_date is null
and g.gene_id = gn.gene_id
and gn.obsolescence_date is null
and gn.node_id = n.node_id
and n.obsolescence_date is null
and g.primary_ext_acc = g1.primary_ext_acc
and n.accession = n1.accession
;
$$;


ALTER FUNCTION panther_upl.step012_000_update_gene_node(cls_version_sid integer) OWNER TO postgres;

--
-- TOC entry 759 (class 1255 OID 779099175)
-- Name: step013_000_update_protein_node(integer); Type: FUNCTION; Schema: panther_upl; Owner: postgres
--

CREATE FUNCTION step013_000_update_protein_node(cls_version_sid integer) RETURNS void
    LANGUAGE sql
    AS $$
/*
   This function is to update the protein_node table.
   Please note that the protein_node table in panther_load schema was used because it took too long to query through the panther_upl schema.
   
*/   
insert into panther.protein_node
(protein_node_id, protein_id, node_id, created_by, creation_date)
select nextval('panther.panther_uids'), p.protein_id, n.node_id, n.created_by, n.creation_date 
from panther_load.protein_node pn, panther.protein p, panther.node n
where p.classification_version_sid = cls_version_sid
and p.obsolescence_date is null
and p.primary_ext_id = pn.protein_ext_id
and pn.node_accession = n.accession
and n.classification_version_sid = cls_version_sid
;
$$;


ALTER FUNCTION panther_upl.step013_000_update_protein_node(cls_version_sid integer) OWNER TO postgres;

--
-- TOC entry 760 (class 1255 OID 780163256)
-- Name: step014_000_update_node_relationship(integer); Type: FUNCTION; Schema: panther_upl; Owner: postgres
--

CREATE FUNCTION step014_000_update_node_relationship(cls_version_sid integer) RETURNS void
    LANGUAGE sql
    AS $$
/*
   This function is to update the node_relationship table.
   
*/   
insert into panther.node_relationship
(node_relationship_id, parent_node_id, child_node_id, created_by, creation_date)
select nextval('panther.panther_uids'), n3.node_id, n4.node_id, r.created_by, r.creation_date
from panther_upl.node_relationship r, panther_upl.node n1, panther_upl.node n2, panther.node n3, panther.node n4
where n1.classification_version_sid = cls_version_sid
and n1.obsolescence_date is null
and n1.node_id = r.parent_node_id
and r.obsolescence_date is null
and r.child_node_id = n2.node_id
and n2.obsolescence_date is null
and n1.accession = n3.accession
and n2.accession = n4.accession
;
$$;


ALTER FUNCTION panther_upl.step014_000_update_node_relationship(cls_version_sid integer) OWNER TO postgres;

--
-- TOC entry 741 (class 1255 OID 781964328)
-- Name: step015_000_update_identifier(integer); Type: FUNCTION; Schema: panther_upl; Owner: postgres
--

CREATE FUNCTION step015_000_update_identifier(cls_version_sid integer) RETURNS void
    LANGUAGE sql
    AS $$
/*
   This function is to update the identifier table.
   
*/   
insert into panther.identifier
(identifier_id, identifier_type_sid, primary_object_id, name, created_by, creation_date)
select nextval('panther.panther_uids'), i.identifier_type_sid, p1.protein_id, i.name, i.created_by, i.creation_date 
from panther_upl.identifier i, panther_upl.protein p, panther.protein p1
where p.classification_version_sid = cls_version_sid
and p.obsolescence_date is null
and p.protein_id = i.primary_object_id
and i.obsolescence_date is null
and p.primary_ext_id = p1.primary_ext_id
;
$$;


ALTER FUNCTION panther_upl.step015_000_update_identifier(cls_version_sid integer) OWNER TO postgres;

--
-- TOC entry 739 (class 1255 OID 799323489)
-- Name: step016_000_update_annotation(integer); Type: FUNCTION; Schema: panther_upl; Owner: postgres
--

CREATE FUNCTION step016_000_update_annotation(cls_version_sid integer) RETURNS void
    LANGUAGE sql
    AS $$

/*
   This function is to update the annotation table.
   
*/   
insert into panther.annotation
(annotation_id, node_id, classification_id, annotation_type_id, created_by, creation_date)
select nextval('panther.panther_uids'), n1.node_id, c1.classification_id, t1.annotation_type_id, a.created_by, a.creation_date 
from panther_upl.annotation a, panther_upl.node n, panther_upl.classification c, panther.node n1, panther.classification c1, panther_upl.annotation_type t, panther.annotation_type t1
where n.classification_version_sid = cls_version_sid
and n.obsolescence_date is null
and n.node_id = a.node_id
and a.obsolescence_date is null
and a.classification_id = c.classification_id
and c.obsolescence_date is null
and a.annotation_type_id = t.annotation_type_id
and n.accession = n1.accession
and n1.obsolescence_date is null
and c.accession = c1.accession
and c1.obsolescence_date is null
and t.annotation_type = t1.annotation_type
;
$$;


ALTER FUNCTION panther_upl.step016_000_update_annotation(cls_version_sid integer) OWNER TO postgres;

--
-- TOC entry 748 (class 1255 OID 799504259)
-- Name: step017_000_update_annotation_qualifier(integer); Type: FUNCTION; Schema: panther_upl; Owner: postgres
--

CREATE FUNCTION step017_000_update_annotation_qualifier(cls_version_sid integer) RETURNS void
    LANGUAGE sql
    AS $$

/*
   This function is to update the annotation_qualifier table.
   Note: When v11 was built the annotation_qualifier_id was missing the in the function. The function was updated, 
   but has not been rerun on the v11 data.
      
*/   
insert into panther.annotation_qualifier
(annotation_qualifier_id, annotation_id, qualifier_id)
select nextval('panther.panther_uids'), a1.annotation_id, q1.qualifier_id
from panther_upl.annotation a, panther_upl.annotation_qualifier aq, panther_upl.node n, panther_upl.classification c, panther_upl.qualifier q,
panther.annotation a1, panther.node n1, panther.classification c1, panther.qualifier q1
where n.classification_version_sid = cls_version_sid
and a.node_id = n.node_id
and a.obsolescence_date is null
and n.obsolescence_date is null
and a.classification_id = c.classification_id
and c.obsolescence_date is null
and a.annotation_id = aq.annotation_id
and aq.qualifier_id = q.qualifier_id
and n.accession = n1.accession
and c.accession = c1.accession
and q.qualifier = q1.qualifier
and a1.node_id = n1.node_id
and a1.classification_id = c1.classification_id
;
$$;


ALTER FUNCTION panther_upl.step017_000_update_annotation_qualifier(cls_version_sid integer) OWNER TO postgres;

--
-- TOC entry 740 (class 1255 OID 799504227)
-- Name: step018_000_update_confidence_code(); Type: FUNCTION; Schema: panther_upl; Owner: postgres
--

CREATE FUNCTION step018_000_update_confidence_code() RETURNS void
    LANGUAGE sql
    AS $$

/*
   This function is to update the confidence_code table.
   This table should be treated as other "_type" files and be copied when the table is generated.
   
*/   
insert into panther.confidence_code
(confidence_code_sid, confidence_code, name, evidence_requirement, description)
select c.confidence_code_sid, c.confidence_code, c.name, c.evidence_requirement, c.description
from panther_upl.confidence_code c
;
$$;


ALTER FUNCTION panther_upl.step018_000_update_confidence_code() OWNER TO postgres;

--
-- TOC entry 761 (class 1255 OID 799508680)
-- Name: step019_000_update_pathway_curation(integer); Type: FUNCTION; Schema: panther_upl; Owner: postgres
--

CREATE FUNCTION step019_000_update_pathway_curation(cls_version_sid integer) RETURNS void
    LANGUAGE sql
    AS $$

/*
   This function is to update the pathway_curation table.
   This table should be treated as other "_type" files and be copied when the table is generated.
   
*/   
insert into panther.pathway_curation
(pathway_curation_id, classification_id, protein_id, confidence_code_sid, created_by, creation_date)
select nextval('panther.panther_uids'), c1.classification_id, p1.protein_id, cc1.confidence_code_sid, pc.created_by, pc.creation_date
from panther_upl.pathway_curation pc, panther_upl.protein p, panther_upl.classification c, panther_upl.confidence_code cc,
panther.protein p1, panther.classification c1, panther.confidence_code cc1
where p.classification_version_sid = cls_version_sid
and p.protein_id = pc.protein_id
and pc.obsolescence_date is null
and pc.classification_id = c.classification_id
and pc.confidence_code_sid = cc.confidence_code_sid
and p.primary_ext_id = p1.primary_ext_id
and c.accession = c1.accession
and cc.confidence_code = cc1.confidence_code
;
$$;


ALTER FUNCTION panther_upl.step019_000_update_pathway_curation(cls_version_sid integer) OWNER TO postgres;

--
-- TOC entry 787 (class 1255 OID 802508214)
-- Name: step020_000_update_evidence(integer, integer); Type: FUNCTION; Schema: panther_upl; Owner: postgres
--

CREATE FUNCTION step020_000_update_evidence(cls_version_sid integer, pthwy_version_sid integer) RETURNS void
    LANGUAGE sql
    AS $$

/*
   This function is to update the evidence table for the pathway curation.This table should be treated as other "_type" files and be copied when the table is generated.
   
*/   
insert into panther.evidence
(evidence_id, evidence_type_sid, evidence, is_editable, creation_date, pathway_curation_id)
select nextval('panther.panther_uids'), e.evidence_type_sid, e.evidence, 1, e.creation_date, pc1.pathway_curation_id 
from panther_load.pathway_evidence e, panther_upl.pathway_curation pc, panther_old.protein p, panther_old.node n, panther_old.protein_node pn, panther.protein p1, panther.node n1, panther.protein_node pn1, panther_upl.protein p2,panther_upl.classification c,
panther.pathway_curation pc1, panther.classification c1
where p.classification_version_sid = 21
and p2.protein_id = pc.protein_id
and p2.classification_version_sid = 21
and pc.pathway_curation_id = e.pathway_curation_id
and pc.classification_id = c.classification_id
and c.classification_version_sid = pthwy_version_sid
and c.accession = c1.accession
and p.protein_id = pn.protein_id
and pn.node_id = n.node_id
and n.public_id = n1.public_id
and n1.node_id = pn1.node_id
and pn1.protein_id = p1.protein_id
and p1.classification_version_sid = cls_version_sid
and p1.primary_ext_id = p2.primary_ext_id
and p1.protein_id = pc1.protein_id
and c1.classification_id = pc1.classification_id
and c1.classification_version_sid = pthwy_version_sid
and pc.created_by = pc1.created_by
and pc.creation_date = pc1.creation_date
and pc.confidence_code_sid = pc1.confidence_code_sid
;
$$;


ALTER FUNCTION panther_upl.step020_000_update_evidence(cls_version_sid integer, pthwy_version_sid integer) OWNER TO postgres;

--
-- TOC entry 799 (class 1255 OID 1408730679)
-- Name: step020_000_update_evidence_upl12(integer, integer); Type: FUNCTION; Schema: panther_upl; Owner: postgres
--

CREATE FUNCTION step020_000_update_evidence_upl12(cls_version_sid integer, pthwy_version_sid integer) RETURNS void
    LANGUAGE sql
    AS $$

/*
   This function is to update the evidence table for the pathway curation.This table should be treated as other "_type" files and be copied when the table is generated.
   
*/   
insert into panther.evidence
(evidence_id, evidence_type_sid, evidence, is_editable, creation_date, pathway_curation_id)
select nextval('panther.panther_uids'), et.evidence_type_sid, lpc.evidence, 1, lpc.creation_date, pc1.pathway_curation_id 
from panther_load.pathway_curation lpc, panther.gene g, panther.protein p, panther.transcript t, panther.pathway_curation pc1, panther.classification c1, panther.confidence_code cc, panther.evidence_type et 
where g.primary_ext_acc = lpc.gene
and p.protein_id = pc1.protein_id
and g.gene_id = t.gene_id
and p.transcript_id = t.transcript_id
and p.classification_version_sid = cls_version_sid
and c1.classification_id = pc1.classification_id
and c1.classification_version_sid = pthwy_version_sid
and lpc.accession = c1.accession
and et.type = lpc.evidence_type
and cc.confidence_code = lpc.confidence
and cc.confidence_code_sid = pc1.confidence_code_sid
and lpc.created_by = pc1.created_by
and lpc.creation_date = pc1.creation_date
;
$$;


ALTER FUNCTION panther_upl.step020_000_update_evidence_upl12(cls_version_sid integer, pthwy_version_sid integer) OWNER TO postgres;

--
-- TOC entry 762 (class 1255 OID 835466299)
-- Name: step020_001_update_evidence(integer); Type: FUNCTION; Schema: panther_upl; Owner: postgres
--

CREATE FUNCTION step020_001_update_evidence(pthwy_version_sid integer) RETURNS void
    LANGUAGE sql
    AS $$

/*
   This function is to update the evidence table for the pathway and pathway component level references.
   
*/   
insert into panther.evidence
(evidence_id, evidence_type_sid, classification_id, evidence, is_editable, created_by, creation_date)
select nextval('panther.panther_uids'), e1.evidence_type_sid, c2.classification_id, e1.evidence, e1.is_editable, e1.created_by, e1.creation_date
from panther_upl.evidence e1, panther_upl.classification c1, panther.classification c2
where c1.classification_version_sid = pthwy_version_sid
and c1.obsolescence_date is null
and c1.accession = c2.accession
and c2.classification_version_sid = pthwy_version_sid
and c1. classification_id = e1.classification_id
and e1.obsolescence_date is null
;
$$;


ALTER FUNCTION panther_upl.step020_001_update_evidence(pthwy_version_sid integer) OWNER TO postgres;

--
-- TOC entry 763 (class 1255 OID 802527921)
-- Name: step021_000_update_map_location(integer); Type: FUNCTION; Schema: panther_upl; Owner: postgres
--

CREATE FUNCTION step021_000_update_map_location(cls_version_sid integer) RETURNS void
    LANGUAGE sql
    AS $$

/*
   This function is to update the chromosome location data in the map_location table in the panther schema.
   
*/   
insert into panther.map_location
(location_id, primary_object_id, location_type_sid, start_pos, end_pos, chromosome, orientation, creation_date)
select nextval('panther.panther_uids'), g.gene_id, 11, l.start_pos, l.end_pos, l.chr, l.orientation, now() 
from panther.temp_location l, panther.gene g
where g.classification_version_sid = cls_version_sid
and g.primary_ext_id = l.gene
;
$$;


ALTER FUNCTION panther_upl.step021_000_update_map_location(cls_version_sid integer) OWNER TO postgres;

--
-- TOC entry 764 (class 1255 OID 802547626)
-- Name: step022_000_update_classification_relationship_with_sf_cat(integer, integer, integer); Type: FUNCTION; Schema: panther_upl; Owner: postgres
--

CREATE FUNCTION step022_000_update_classification_relationship_with_sf_cat(cls_version_sid integer, cat_version_sid integer, ont_version_sid integer) RETURNS void
    LANGUAGE sql
    AS $$
/*
   This function is to copy the family/subfamily tp GO/PC classification relationship.
   
*/   
insert into panther.classification_relationship
(classification_relationship_id, parent_classification_id, child_classification_id, relationship_type_sid, created_by, creation_date)
select nextval('panther.panther_uids'), c4.classification_id, c3.classification_id, r.relationship_type_sid, r.created_by, r.creation_date
from panther_upl.classification c1, panther_upl.classification c2, panther_upl.classification_relationship r, panther.classification c3, panther.classification c4
where c1.classification_id = r.child_classification_id
and c1.classification_version_sid = cls_version_sid
and c1.obsolescence_date is null
and r.parent_classification_id = c2.classification_id
and c2.classification_version_sid = cat_version_sid
and c2.obsolescence_date is null
and c1.accession = c3.accession
and c3.classification_version_sid = cls_version_sid
and c2.accession = c4.accession
and c4.classification_version_sid = ont_version_sid;
$$;


ALTER FUNCTION panther_upl.step022_000_update_classification_relationship_with_sf_cat(cls_version_sid integer, cat_version_sid integer, ont_version_sid integer) OWNER TO postgres;

--
-- TOC entry 765 (class 1255 OID 818485419)
-- Name: step023_000_update_protein_classification(integer); Type: FUNCTION; Schema: panther_upl; Owner: postgres
--

CREATE FUNCTION step023_000_update_protein_classification(cls_version_sid integer) RETURNS void
    LANGUAGE sql
    AS $$
/*
   This function is to copy protein classification table.
   
*/   
insert into panther.protein_classification
(protein_classification_id, classification_id, protein_id, created_by, creation_date)
select nextval('panther.panther_uids'), c2.classification_id, p2.protein_id, pc.created_by, pc.creation_date 
from panther_upl.protein_classification pc, panther_upl.protein p1, panther.protein p2, panther_upl.classification c1, panther.classification c2
where pc.obsolescence_date is null
and pc.protein_id = p1.protein_id
and p1.classification_version_sid = cls_version_sid
and p1.obsolescence_date is null
and pc.classification_id = c1.classification_id
and c1.classification_version_sid = cls_version_sid
and c1.obsolescence_date is null
and c1.accession = c2.accession
and c2.classification_version_sid = cls_version_sid
and p1.primary_ext_id = p2.primary_ext_id
and p2.classification_version_sid = cls_version_sid
and c2.obsolescence_date is null
and p2.obsolescence_date is null;
$$;


ALTER FUNCTION panther_upl.step023_000_update_protein_classification(cls_version_sid integer) OWNER TO postgres;

--
-- TOC entry 788 (class 1255 OID 1406915916)
-- Name: trig_refresh_classification_table_view(); Type: FUNCTION; Schema: panther_upl; Owner: postgres
--

CREATE FUNCTION trig_refresh_classification_table_view() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    REFRESH MATERIALIZED VIEW classification_table_view;
    RETURN NULL;
END;
$$;


ALTER FUNCTION panther_upl.trig_refresh_classification_table_view() OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- TOC entry 337 (class 1259 OID 16991)
-- Name: abstract; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE abstract (
    abstract_id bigint NOT NULL,
    abstract_type_sid integer,
    classification_id bigint,
    content character varying(4000),
    created_by integer,
    creation_date timestamp without time zone,
    obsoleted_by integer,
    obsolescence_date timestamp without time zone,
    is_formatted smallint
);


ALTER TABLE abstract OWNER TO panther_upl;

--
-- TOC entry 338 (class 1259 OID 16997)
-- Name: abstract_type; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE abstract_type (
    abstract_type_sid integer NOT NULL,
    type character varying(32),
    description character varying(128)
);


ALTER TABLE abstract_type OWNER TO panther_upl;

--
-- TOC entry 339 (class 1259 OID 17000)
-- Name: add_cat_subfam; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE add_cat_subfam (
    sf_acc character varying(32),
    cat_acc character varying(32)
);


ALTER TABLE add_cat_subfam OWNER TO panther_upl;

--
-- TOC entry 340 (class 1259 OID 17003)
-- Name: annotation; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE annotation (
    annotation_id bigint NOT NULL,
    node_id bigint,
    classification_id bigint,
    annotation_type_id bigint,
    created_by integer,
    creation_date timestamp without time zone,
    obsoleted_by integer,
    obsolescence_date timestamp without time zone
);


ALTER TABLE annotation OWNER TO panther_upl;

--
-- TOC entry 341 (class 1259 OID 17006)
-- Name: annotation_qualifier; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE annotation_qualifier (
    annotation_qualifier_id bigint NOT NULL,
    annotation_id bigint,
    qualifier_id bigint
);


ALTER TABLE annotation_qualifier OWNER TO panther_upl;

--
-- TOC entry 342 (class 1259 OID 17009)
-- Name: annotation_type; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE annotation_type (
    annotation_type_id bigint NOT NULL,
    annotation_type character varying(32)
);


ALTER TABLE annotation_type OWNER TO panther_upl;

--
-- TOC entry 343 (class 1259 OID 17012)
-- Name: bio_sequence; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE bio_sequence (
    seq_id bigint NOT NULL,
    protein_id bigint,
    type integer,
    length integer,
    text text
);


ALTER TABLE bio_sequence OWNER TO panther_upl;

--
-- TOC entry 344 (class 1259 OID 17018)
-- Name: cat_relation; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE cat_relation (
    name character varying(256),
    accession character varying(32),
    child_classification_id bigint
);


ALTER TABLE cat_relation OWNER TO panther_upl;

--
-- TOC entry 345 (class 1259 OID 17021)
-- Name: classification; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE classification (
    classification_id bigint NOT NULL,
    classification_version_sid integer,
    depth integer,
    name character varying(256),
    accession character varying(32),
    definition character varying(4000),
    created_by integer,
    creation_date timestamp without time zone,
    obsoleted_by integer,
    obsolescence_date timestamp without time zone,
    evalue_cutoff character varying(32),
    alt_acc character varying(32),
    term_type_sid integer,
    group_id integer,
    long_name character varying(512),
    revision_version_sid integer
)
WITH (autovacuum_enabled=false);


ALTER TABLE classification OWNER TO panther_upl;

--
-- TOC entry 346 (class 1259 OID 17027)
-- Name: classification_mapping; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE classification_mapping (
    new_cls_id bigint,
    old_cls_id bigint,
    depth integer
);


ALTER TABLE classification_mapping OWNER TO panther_upl;

--
-- TOC entry 494 (class 1259 OID 1374928202)
-- Name: classification_production; Type: FOREIGN TABLE; Schema: panther_upl; Owner: postgres; Tablespace: 
--

CREATE FOREIGN TABLE classification_production (
    classification_id numeric(20,0) NOT NULL,
    classification_version_sid numeric(6,0) NOT NULL,
    depth numeric(2,0),
    name character varying(256),
    accession character varying(32),
    definition character varying(4000),
    created_by numeric(6,0),
    creation_date timestamp(0) without time zone,
    obsoleted_by numeric(6,0),
    obsolescence_date timestamp(0) without time zone,
    revision_id numeric(6,0),
    alt_acc character varying(32),
    long_name character varying(512),
    term_type_sid numeric(6,0)
)
SERVER pantherdb
OPTIONS (
    schema_name 'panther',
    table_name 'classification'
);


ALTER FOREIGN TABLE classification_production OWNER TO postgres;

--
-- TOC entry 347 (class 1259 OID 17030)
-- Name: classification_relationship; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE classification_relationship (
    classification_relationship_id bigint NOT NULL,
    parent_classification_id bigint,
    child_classification_id bigint,
    relationship_type_sid integer,
    rank integer,
    created_by integer,
    creation_date timestamp without time zone,
    obsoleted_by integer,
    obsolescence_date timestamp without time zone,
    overlap numeric(6,2),
    overlap_unit character varying(16)
);


ALTER TABLE classification_relationship OWNER TO panther_upl;

--
-- TOC entry 649 (class 1259 OID 1406915909)
-- Name: classification_table_view; Type: MATERIALIZED VIEW; Schema: panther_upl; Owner: postgres; Tablespace: 
--

CREATE MATERIALIZED VIEW classification_table_view AS
 SELECT classification.classification_id,
    classification.classification_version_sid,
    classification.depth,
    classification.name,
    classification.accession,
    classification.definition,
    classification.created_by,
    classification.creation_date,
    classification.obsoleted_by,
    classification.obsolescence_date,
    classification.evalue_cutoff,
    classification.alt_acc,
    classification.term_type_sid,
    classification.group_id,
    classification.long_name,
    classification.revision_version_sid
   FROM classification
  WITH NO DATA;


ALTER TABLE classification_table_view OWNER TO postgres;

--
-- TOC entry 348 (class 1259 OID 17033)
-- Name: classification_term_type; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE classification_term_type (
    term_type_sid integer NOT NULL,
    term_name character varying(32),
    term_description character varying(256),
    accession_format character varying(10)
);


ALTER TABLE classification_term_type OWNER TO panther_upl;

--
-- TOC entry 349 (class 1259 OID 17036)
-- Name: classification_type; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE classification_type (
    classification_type_sid bigint NOT NULL,
    name character varying(32),
    description character varying(256)
);


ALTER TABLE classification_type OWNER TO panther_upl;

--
-- TOC entry 350 (class 1259 OID 17039)
-- Name: classification_version; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE classification_version (
    classification_version_sid integer NOT NULL,
    classification_type_sid integer,
    version character varying(64),
    creation_date timestamp without time zone,
    obsolescence_date timestamp without time zone,
    release_date timestamp without time zone
);


ALTER TABLE classification_version OWNER TO panther_upl;

--
-- TOC entry 351 (class 1259 OID 17042)
-- Name: comments; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE comments (
    comment_id bigint NOT NULL,
    classification_id bigint,
    protein_id bigint,
    remark text,
    created_by integer,
    creation_date timestamp without time zone,
    obsoleted_by integer,
    obsolescence_date timestamp without time zone,
    node_id bigint
);


ALTER TABLE comments OWNER TO panther_upl;

--
-- TOC entry 352 (class 1259 OID 17048)
-- Name: common_annotation_block; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE common_annotation_block (
    block_id bigint NOT NULL,
    accession character varying(16),
    name character varying(50),
    text character varying(4000),
    creation_date timestamp without time zone,
    obsolescence_date timestamp without time zone
);


ALTER TABLE common_annotation_block OWNER TO panther_upl;

--
-- TOC entry 353 (class 1259 OID 17054)
-- Name: confidence_code; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE confidence_code (
    confidence_code_sid integer NOT NULL,
    confidence_code character varying(16),
    name character varying(64),
    evidence_requirement character(1),
    description character varying(512)
);


ALTER TABLE confidence_code OWNER TO panther_upl;

--
-- TOC entry 354 (class 1259 OID 17060)
-- Name: curation_status; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE curation_status (
    curation_status_id bigint NOT NULL,
    status_type_sid integer,
    classification_id bigint,
    user_id bigint,
    creation_date timestamp without time zone,
    protein_id bigint,
    classification_relationship_id bigint,
    pathway_curation_id bigint
);


ALTER TABLE curation_status OWNER TO panther_upl;

--
-- TOC entry 677 (class 1259 OID 1526167854)
-- Name: curation_status_new_v12; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE curation_status_new_v12 (
    curation_status_id bigint NOT NULL,
    status_type_sid integer,
    classification_id bigint,
    user_id bigint,
    creation_date timestamp without time zone,
    protein_id bigint,
    classification_relationship_id bigint,
    pathway_curation_id bigint
);


ALTER TABLE curation_status_new_v12 OWNER TO panther_upl;

--
-- TOC entry 355 (class 1259 OID 17063)
-- Name: curation_status_type; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE curation_status_type (
    status_type_sid integer NOT NULL,
    status character varying(64)
);


ALTER TABLE curation_status_type OWNER TO panther_upl;

--
-- TOC entry 356 (class 1259 OID 17066)
-- Name: event_type; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE event_type (
    event_type_id bigint NOT NULL,
    event_type character varying(32)
);


ALTER TABLE event_type OWNER TO panther_upl;

--
-- TOC entry 460 (class 1259 OID 702595566)
-- Name: evidence; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE evidence (
    evidence_id bigint,
    evidence_type_sid bigint,
    classification_id bigint,
    protein_id bigint,
    evidence character varying(1000),
    is_editable integer,
    created_by character varying(64),
    creation_date timestamp without time zone,
    obsoleted_by character varying(64),
    obsolescence_date timestamp without time zone,
    updated_by character varying(64),
    update_date timestamp without time zone,
    pathway_curation_id bigint,
    confidence_code_sid integer,
    annotation_id bigint,
    protein_classification_id bigint
);


ALTER TABLE evidence OWNER TO panther_upl;

--
-- TOC entry 5094 (class 0 OID 0)
-- Dependencies: 460
-- Name: TABLE evidence; Type: COMMENT; Schema: panther_upl; Owner: panther_upl
--

COMMENT ON TABLE evidence IS 'The original evidence table missed the evidence_id column. In order to add the evidence_id column as the first column of the table, a new table (this one) had to be created. The process was to create a new table with the evidence_id column, copy all data from this table to the new table, and then rename this table to evidence_old, and the new table as evidence.';


--
-- TOC entry 357 (class 1259 OID 17069)
-- Name: evidence_old; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE evidence_old (
    evidence_type_sid bigint,
    classification_id bigint,
    protein_id bigint,
    evidence character varying(1000),
    is_editable integer,
    created_by character varying(64),
    creation_date timestamp without time zone,
    obsoleted_by character varying(64),
    obsolescence_date timestamp without time zone,
    updated_by character varying(64),
    update_date timestamp without time zone,
    pathway_curation_id bigint,
    confidence_code_sid integer,
    annotation_id bigint,
    protein_classification_id bigint,
    evidence_id bigint
);


ALTER TABLE evidence_old OWNER TO panther_upl;

--
-- TOC entry 5096 (class 0 OID 0)
-- Dependencies: 357
-- Name: TABLE evidence_old; Type: COMMENT; Schema: panther_upl; Owner: panther_upl
--

COMMENT ON TABLE evidence_old IS 'This was the original evidence table. It missed the evidence_id column. In order to add the evidence_id column as the first column of the table, a new table had to be created. The process was to create a new table with the evidence_id column, copy all data from this table to the new table, and then rename this table to evidence_old, and the new table as evidence.';


--
-- TOC entry 358 (class 1259 OID 17075)
-- Name: evidence_type; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE evidence_type (
    evidence_type_sid bigint NOT NULL,
    type character varying(32),
    description character varying(128)
);


ALTER TABLE evidence_type OWNER TO panther_upl;

--
-- TOC entry 359 (class 1259 OID 17078)
-- Name: family_to_sequence_save; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE family_to_sequence_save (
    family_acc character varying(32),
    protein_id bigint,
    protein_ext_id character varying(32),
    protein_ext_acc character varying(32),
    classification_version_sid integer
);


ALTER TABLE family_to_sequence_save OWNER TO panther_upl;

--
-- TOC entry 360 (class 1259 OID 17081)
-- Name: feature; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE feature (
    feature_id bigint,
    feature_type_sid bigint,
    protein_id bigint,
    classification_id bigint,
    primary_ext_id character varying(32),
    primary_ext_acc character varying(32),
    name character varying(256),
    definition character varying(1000),
    seq_start integer,
    seq_end integer,
    seq_range character varying(1000),
    mod_start integer,
    mod_end integer,
    mod_range character varying(1000),
    creation_date timestamp without time zone,
    obsolescence_date timestamp without time zone,
    created_by integer,
    obsoleted_by integer
);


ALTER TABLE feature OWNER TO panther_upl;

--
-- TOC entry 361 (class 1259 OID 17087)
-- Name: feature_type; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE feature_type (
    feature_type_sid bigint NOT NULL,
    type character varying(64),
    description character varying(256)
);


ALTER TABLE feature_type OWNER TO panther_upl;

--
-- TOC entry 362 (class 1259 OID 17090)
-- Name: fill_parent_category; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE fill_parent_category (
    category_id bigint,
    subfamily_id bigint
);


ALTER TABLE fill_parent_category OWNER TO panther_upl;

--
-- TOC entry 363 (class 1259 OID 17093)
-- Name: gene; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE gene (
    gene_id bigint,
    primary_ext_id character varying(128),
    primary_ext_acc character varying(128),
    gene_name character varying(512),
    gene_symbol character varying(128),
    created_by integer,
    creation_date timestamp without time zone,
    obsoleted_by integer,
    obsolescence_date timestamp without time zone,
    classification_version_sid integer,
    ext_db_gene_id character varying(128)
);


ALTER TABLE gene OWNER TO panther_upl;

--
-- TOC entry 364 (class 1259 OID 17099)
-- Name: gene_node; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE gene_node (
    gene_node_id bigint NOT NULL,
    gene_id bigint,
    node_id bigint,
    created_by integer,
    creation_date timestamp without time zone,
    obsoleted_by integer,
    obsolescence_date timestamp without time zone
);


ALTER TABLE gene_node OWNER TO panther_upl;

--
-- TOC entry 478 (class 1259 OID 1362824023)
-- Name: gene_node_production; Type: FOREIGN TABLE; Schema: panther_upl; Owner: postgres; Tablespace: 
--

CREATE FOREIGN TABLE gene_node_production (
    gene_node_id numeric(38,0) NOT NULL,
    gene_id numeric(38,0),
    node_id numeric(38,0),
    created_by numeric(6,0),
    creation_date timestamp(0) without time zone,
    obsoleted_by numeric(6,0),
    obsolescence_date timestamp(0) without time zone
)
SERVER pantherdb
OPTIONS (
    schema_name 'panther',
    table_name 'gene_node'
);


ALTER FOREIGN TABLE gene_node_production OWNER TO postgres;

--
-- TOC entry 479 (class 1259 OID 1362824026)
-- Name: gene_production; Type: FOREIGN TABLE; Schema: panther_upl; Owner: postgres; Tablespace: 
--

CREATE FOREIGN TABLE gene_production (
    gene_id numeric(20,0) NOT NULL,
    primary_ext_id character varying(128),
    primary_ext_acc character varying(128),
    gene_name character varying(512),
    gene_symbol character varying(128),
    created_by numeric(6,0),
    creation_date timestamp(0) without time zone,
    obsoleted_by numeric(6,0),
    ext_id_uid numeric(20,0),
    ext_acc_uid numeric(20,0),
    obsolescence_date timestamp(0) without time zone,
    classification_version_sid numeric(6,0),
    ext_db_gene_id character varying(64)
)
SERVER pantherdb
OPTIONS (
    schema_name 'panther',
    table_name 'gene'
);


ALTER FOREIGN TABLE gene_production OWNER TO postgres;

--
-- TOC entry 365 (class 1259 OID 17102)
-- Name: gene_protein; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE gene_protein (
    gene_protein_id bigint,
    gene_id bigint,
    protein_id bigint,
    obsolescence_date timestamp without time zone,
    obsoleted_by integer
);


ALTER TABLE gene_protein OWNER TO panther_upl;

--
-- TOC entry 489 (class 1259 OID 1362824211)
-- Name: genelist_agg; Type: FOREIGN TABLE; Schema: panther_upl; Owner: postgres; Tablespace: 
--

CREATE FOREIGN TABLE genelist_agg (
    gene_id numeric(20,0) NOT NULL,
    gene_name character varying(512),
    gene_symbol character varying(128),
    genex_assay character varying(4000),
    snp_assay text,
    panther_best_hit character varying(4000),
    panther_best_hit_name character varying(256),
    panther_best_hit_acc character varying(32),
    panther_best_hit_score numeric(38,0),
    panther_mf character varying(4000),
    panther_bp character varying(4000),
    transcripts character varying(4000),
    proteins character varying(4000),
    cytoband character varying(64),
    cytoband_sort character varying(256),
    species character varying(32),
    genelist_rowuid bigint NOT NULL,
    cra_chromosome character varying(32),
    cra_start_pos numeric(38,0),
    cra_end_pos numeric(38,0),
    pub_chromosome character varying(32),
    pub_start_pos numeric(38,0),
    pub_end_pos numeric(38,0),
    source_id numeric(20,0),
    gene_ext_id character varying(128),
    gene_ext_acc character varying(128),
    cra_chromosome_rank numeric(2,0),
    pub_chromosome_rank numeric(2,0),
    pathway character varying(4000),
    panther_cc character varying(4000),
    panther_pc character varying(4000),
    fullgo_mf_exp character varying(4000),
    fullgo_mf_comp character varying(4000),
    fullgo_bp_exp character varying(4000),
    fullgo_bp_comp character varying(4000),
    fullgo_cc_exp character varying(4000),
    fullgo_cc_comp character varying(4000),
    public_id character varying(32),
    reactome character varying(40000)
)
SERVER pantherdb
OPTIONS (
    schema_name 'panther',
    table_name 'genelist_agg'
);


ALTER FOREIGN TABLE genelist_agg OWNER TO postgres;

--
-- TOC entry 684 (class 1259 OID 1541580915)
-- Name: genelist_agg_v12_test; Type: FOREIGN TABLE; Schema: panther_upl; Owner: postgres; Tablespace: 
--

CREATE FOREIGN TABLE genelist_agg_v12_test (
    gene_id numeric(20,0) NOT NULL,
    gene_name character varying(512),
    gene_symbol character varying(128),
    genex_assay character varying(4000),
    snp_assay text,
    panther_best_hit character varying(4000),
    panther_best_hit_name character varying(256),
    panther_best_hit_acc character varying(32),
    panther_best_hit_score numeric(38,0),
    panther_mf character varying(4000),
    panther_bp character varying(4000),
    transcripts character varying(4000),
    proteins character varying(4000),
    cytoband character varying(64),
    cytoband_sort character varying(256),
    species character varying(32),
    genelist_rowuid bigint NOT NULL,
    cra_chromosome character varying(32),
    cra_start_pos numeric(38,0),
    cra_end_pos numeric(38,0),
    pub_chromosome character varying(32),
    pub_start_pos numeric(38,0),
    pub_end_pos numeric(38,0),
    source_id numeric(20,0),
    gene_ext_id character varying(128),
    gene_ext_acc character varying(128),
    cra_chromosome_rank numeric(2,0),
    pub_chromosome_rank numeric(2,0),
    pathway character varying(4000),
    panther_cc character varying(4000),
    panther_pc character varying(4000),
    fullgo_mf_exp character varying(4000),
    fullgo_mf_comp character varying(4000),
    fullgo_bp_exp character varying(4000),
    fullgo_bp_comp character varying(4000),
    fullgo_cc_exp character varying(4000),
    fullgo_cc_comp character varying(4000),
    public_id character varying(32),
    reactome character varying(40000)
)
SERVER panthertestdb
OPTIONS (
    schema_name 'panther',
    table_name 'genelist_agg'
);


ALTER FOREIGN TABLE genelist_agg_v12_test OWNER TO postgres;

SET default_with_oids = true;

--
-- TOC entry 679 (class 1259 OID 1526168539)
-- Name: go_annotation; Type: TABLE; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE TABLE go_annotation (
    annotation_id numeric(38,0),
    node_id numeric(38,0),
    classification_id numeric(38,0),
    annotation_type_id numeric(38,0),
    created_by numeric(6,0),
    creation_date timestamp(0) without time zone,
    obsoleted_by numeric(6,0),
    obsolescence_date timestamp(0) without time zone
);


ALTER TABLE go_annotation OWNER TO panther_isp;

--
-- TOC entry 681 (class 1259 OID 1537948283)
-- Name: go_annotation_qualifier; Type: TABLE; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE TABLE go_annotation_qualifier (
    annotation_qualifier_id numeric(38,0),
    annotation_id numeric(38,0),
    qualifier_id numeric(38,0)
);


ALTER TABLE go_annotation_qualifier OWNER TO panther_isp;

SET default_with_oids = false;

--
-- TOC entry 491 (class 1259 OID 1368951752)
-- Name: go_classification; Type: TABLE; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE TABLE go_classification (
    classification_id numeric(20,0),
    classification_version_sid numeric(6,0),
    depth numeric(2,0),
    name character varying(256),
    accession character varying(32),
    definition character varying(4000),
    created_by numeric(6,0),
    creation_date date,
    obsoleted_by numeric(6,0),
    obsolescence_date date,
    evalue_cutoff character varying(32),
    alt_acc character varying(32),
    term_type_sid numeric(6,0),
    group_id numeric(6,0),
    long_name character varying(512),
    revision_version_sid numeric(6,0),
    replaced_by_acc character varying(32)
);


ALTER TABLE go_classification OWNER TO panther_isp;

--
-- TOC entry 680 (class 1259 OID 1532058332)
-- Name: go_evidence; Type: TABLE; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE TABLE go_evidence (
    evidence_id bigint,
    evidence_type_sid bigint,
    classification_id bigint,
    primary_object_id bigint,
    evidence character varying(1000),
    is_editable integer,
    created_by character varying(64),
    creation_date timestamp without time zone,
    obsoleted_by character varying(64),
    obsolescence_date timestamp without time zone,
    updated_by character varying(64),
    update_date timestamp without time zone,
    pathway_curation_id bigint,
    confidence_code_sid integer,
    annotation_id numeric(38,0),
    protein_classification_id bigint
);


ALTER TABLE go_evidence OWNER TO panther_isp;

--
-- TOC entry 376 (class 1259 OID 17147)
-- Name: node; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE node (
    node_id bigint NOT NULL,
    accession character varying(32),
    public_id character varying(32),
    classification_version_sid integer,
    node_type_id bigint,
    event_type_id bigint,
    branch_length numeric(8,4),
    created_by integer,
    creation_date timestamp without time zone,
    obsoleted_by integer,
    obsolescence_date timestamp without time zone,
    revision_version_sid integer
);


ALTER TABLE node OWNER TO panther_upl;

--
-- TOC entry 400 (class 1259 OID 17234)
-- Name: qualifier; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE qualifier (
    qualifier_id bigint NOT NULL,
    qualifier character varying(32)
);


ALTER TABLE qualifier OWNER TO panther_upl;

--
-- TOC entry 690 (class 1259 OID 1565665114)
-- Name: go_aggregate; Type: MATERIALIZED VIEW; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE MATERIALIZED VIEW go_aggregate AS
 SELECT gpa.annotation_id,
    n.accession,
    clf.accession AS term,
    et.type,
    gpe.evidence_id,
    gpe.evidence,
    cc.confidence_code,
    q.qualifier
   FROM ((((((((( SELECT go_evidence.annotation_id,
            go_evidence.confidence_code_sid,
            go_evidence.evidence_id,
            go_evidence.evidence,
            go_evidence.evidence_type_sid
           FROM go_evidence
          WHERE (go_evidence.obsolescence_date IS NULL)) gpe
     JOIN ( SELECT go_annotation.annotation_id,
            go_annotation.node_id,
            go_annotation.annotation_type_id,
            go_annotation.classification_id
           FROM go_annotation
          WHERE (go_annotation.obsolescence_date IS NULL)) gpa ON ((gpe.annotation_id = gpa.annotation_id)))
     JOIN confidence_code cc ON (((gpe.confidence_code_sid)::numeric = (cc.confidence_code_sid)::numeric)))
     JOIN node n ON ((gpa.node_id = (n.node_id)::numeric)))
     JOIN annotation_type ant ON (((gpa.annotation_type_id = (ant.annotation_type_id)::numeric) AND ((ant.annotation_type)::text = 'FULLGO'::text))))
     JOIN go_classification clf ON ((gpa.classification_id = clf.classification_id)))
     JOIN evidence_type et ON (((gpe.evidence_type_sid)::numeric = (et.evidence_type_sid)::numeric)))
     LEFT JOIN go_annotation_qualifier gpq ON ((gpa.annotation_id = gpq.annotation_id)))
     LEFT JOIN qualifier q ON ((gpq.qualifier_id = (q.qualifier_id)::numeric)))
  WHERE ((((n.classification_version_sid)::numeric = (21)::numeric) AND (n.obsolescence_date IS NULL)) AND (clf.obsolescence_date IS NULL))
  WITH NO DATA;


ALTER TABLE go_aggregate OWNER TO panther_isp;

SET default_with_oids = true;

--
-- TOC entry 683 (class 1259 OID 1541580898)
-- Name: go_annotation_new_v12; Type: TABLE; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE TABLE go_annotation_new_v12 (
    annotation_id numeric(38,0),
    node_id numeric(38,0),
    classification_id numeric(38,0),
    annotation_type_id numeric(38,0),
    created_by numeric(6,0),
    creation_date timestamp(0) without time zone,
    obsoleted_by numeric(6,0),
    obsolescence_date timestamp(0) without time zone
);


ALTER TABLE go_annotation_new_v12 OWNER TO panther_isp;

--
-- TOC entry 484 (class 1259 OID 1362824182)
-- Name: go_annotation_old; Type: TABLE; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE TABLE go_annotation_old (
    annotation_id numeric(38,0),
    node_id numeric(38,0),
    classification_id numeric(38,0),
    annotation_type_id numeric(38,0),
    created_by numeric(6,0),
    creation_date timestamp(0) without time zone,
    obsoleted_by numeric(6,0),
    obsolescence_date timestamp(0) without time zone
);


ALTER TABLE go_annotation_old OWNER TO panther_isp;

--
-- TOC entry 687 (class 1259 OID 1556463868)
-- Name: go_annotation_qualifier_new_v12; Type: TABLE; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE TABLE go_annotation_qualifier_new_v12 (
    annotation_qualifier_id numeric(38,0),
    annotation_id numeric(38,0),
    qualifier_id numeric(38,0)
);


ALTER TABLE go_annotation_qualifier_new_v12 OWNER TO panther_isp;

--
-- TOC entry 485 (class 1259 OID 1362824188)
-- Name: go_annotation_qualifier_old; Type: TABLE; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE TABLE go_annotation_qualifier_old (
    annotation_qualifier_id numeric(38,0),
    annotation_id numeric(38,0),
    qualifier_id numeric(38,0)
);


ALTER TABLE go_annotation_qualifier_old OWNER TO panther_isp;

SET default_with_oids = false;

--
-- TOC entry 486 (class 1259 OID 1362824191)
-- Name: go_classification_old; Type: TABLE; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE TABLE go_classification_old (
    classification_id numeric(20,0),
    classification_version_sid numeric(6,0),
    depth numeric(2,0),
    name character varying(256),
    accession character varying(32),
    definition character varying(4000),
    created_by numeric(6,0),
    creation_date date,
    obsoleted_by numeric(6,0),
    obsolescence_date date,
    evalue_cutoff character varying(32),
    alt_acc character varying(32),
    term_type_sid numeric(6,0),
    group_id numeric(6,0),
    long_name character varying(512),
    revision_version_sid numeric(6,0),
    replaced_by_acc character varying(32)
);


ALTER TABLE go_classification_old OWNER TO panther_isp;

--
-- TOC entry 492 (class 1259 OID 1368951758)
-- Name: go_classification_relationship; Type: TABLE; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE TABLE go_classification_relationship (
    classification_relationship_id numeric(20,0) NOT NULL,
    parent_classification_id numeric(20,0) NOT NULL,
    child_classification_id numeric(20,0) NOT NULL,
    relationship_type_sid numeric(6,0),
    rank numeric(6,0),
    created_by numeric(6,0),
    creation_date timestamp(0) without time zone,
    obsoleted_by numeric(6,0),
    obsolescence_date timestamp(0) without time zone,
    overlap numeric(6,2),
    overlap_unit character varying(16)
);


ALTER TABLE go_classification_relationship OWNER TO panther_isp;

--
-- TOC entry 487 (class 1259 OID 1362824197)
-- Name: go_classification_relationship_old; Type: TABLE; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE TABLE go_classification_relationship_old (
    classification_relationship_id numeric(20,0) NOT NULL,
    parent_classification_id numeric(20,0) NOT NULL,
    child_classification_id numeric(20,0) NOT NULL,
    relationship_type_sid numeric(6,0),
    rank numeric(6,0),
    created_by numeric(6,0),
    creation_date timestamp(0) without time zone,
    obsoleted_by numeric(6,0),
    obsolescence_date timestamp(0) without time zone,
    overlap numeric(6,2),
    overlap_unit character varying(16)
);


ALTER TABLE go_classification_relationship_old OWNER TO panther_isp;

--
-- TOC entry 686 (class 1259 OID 1556463835)
-- Name: go_evidence_new_v12; Type: TABLE; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE TABLE go_evidence_new_v12 (
    evidence_id bigint,
    evidence_type_sid bigint,
    classification_id bigint,
    primary_object_id bigint,
    evidence character varying(1000),
    is_editable integer,
    created_by character varying(64),
    creation_date timestamp without time zone,
    obsoleted_by character varying(64),
    obsolescence_date timestamp without time zone,
    updated_by character varying(64),
    update_date timestamp without time zone,
    pathway_curation_id bigint,
    confidence_code_sid integer,
    annotation_id numeric(38,0),
    protein_classification_id bigint
);


ALTER TABLE go_evidence_new_v12 OWNER TO panther_isp;

--
-- TOC entry 488 (class 1259 OID 1362824200)
-- Name: go_evidence_old; Type: TABLE; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE TABLE go_evidence_old (
    evidence_id bigint,
    evidence_type_sid bigint,
    classification_id bigint,
    primary_object_id bigint,
    evidence character varying(1000),
    is_editable integer,
    created_by character varying(64),
    creation_date timestamp without time zone,
    obsoleted_by character varying(64),
    obsolescence_date timestamp without time zone,
    updated_by character varying(64),
    update_date timestamp without time zone,
    pathway_curation_id bigint,
    confidence_code_sid integer,
    annotation_id numeric(38,0),
    protein_classification_id bigint
);


ALTER TABLE go_evidence_old OWNER TO panther_isp;

--
-- TOC entry 366 (class 1259 OID 17105)
-- Name: go_isa; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE go_isa (
    parent_go character varying(20),
    child_go character varying(20)
);


ALTER TABLE go_isa OWNER TO panther_upl;

--
-- TOC entry 480 (class 1259 OID 1362824152)
-- Name: goanno_wf; Type: FOREIGN TABLE; Schema: panther_upl; Owner: postgres; Tablespace: 
--

CREATE FOREIGN TABLE goanno_wf (
    geneid character varying(128) NOT NULL,
    go_acc character varying(4000),
    qualifier character varying(32),
    confidence_code character varying(16),
    evi_with character varying(1000),
    evidence character varying(1000)
)
SERVER pantherdb
OPTIONS (
    schema_name 'panther',
    table_name 'goanno_wf'
);


ALTER FOREIGN TABLE goanno_wf OWNER TO postgres;

--
-- TOC entry 685 (class 1259 OID 1556463832)
-- Name: goanno_wf_v12_test; Type: FOREIGN TABLE; Schema: panther_upl; Owner: postgres; Tablespace: 
--

CREATE FOREIGN TABLE goanno_wf_v12_test (
    geneid character varying(128) NOT NULL,
    go_acc character varying(4000),
    qualifier character varying(32),
    confidence_code character varying(16),
    evi_with character varying(1000),
    evidence character varying(1000)
)
SERVER panthertestdb
OPTIONS (
    schema_name 'panther',
    table_name 'goanno_wf'
);


ALTER FOREIGN TABLE goanno_wf_v12_test OWNER TO postgres;

--
-- TOC entry 481 (class 1259 OID 1362824161)
-- Name: gofoo_bp; Type: FOREIGN TABLE; Schema: panther_upl; Owner: postgres; Tablespace: 
--

CREATE FOREIGN TABLE gofoo_bp (
    geneid character varying(128) NOT NULL,
    godetails character varying(4000)
)
SERVER pantherdb
OPTIONS (
    schema_name 'panther',
    table_name 'gofoo_bp'
);


ALTER FOREIGN TABLE gofoo_bp OWNER TO postgres;

--
-- TOC entry 482 (class 1259 OID 1362824164)
-- Name: gofoo_cc; Type: FOREIGN TABLE; Schema: panther_upl; Owner: postgres; Tablespace: 
--

CREATE FOREIGN TABLE gofoo_cc (
    geneid character varying(128) NOT NULL,
    godetails character varying(4000)
)
SERVER pantherdb
OPTIONS (
    schema_name 'panther',
    table_name 'gofoo_cc'
);


ALTER FOREIGN TABLE gofoo_cc OWNER TO postgres;

--
-- TOC entry 483 (class 1259 OID 1362824167)
-- Name: gofoo_mf; Type: FOREIGN TABLE; Schema: panther_upl; Owner: postgres; Tablespace: 
--

CREATE FOREIGN TABLE gofoo_mf (
    geneid character varying(128) NOT NULL,
    godetails character varying(4000)
)
SERVER pantherdb
OPTIONS (
    schema_name 'panther',
    table_name 'gofoo_mf'
);


ALTER FOREIGN TABLE gofoo_mf OWNER TO postgres;

--
-- TOC entry 493 (class 1259 OID 1368951765)
-- Name: goobo_extract; Type: FOREIGN TABLE; Schema: panther_upl; Owner: postgres; Tablespace: 
--

CREATE FOREIGN TABLE goobo_extract (
    accession character varying,
    name character varying,
    term_type_sid integer,
    definition character varying,
    obsolete_date character varying,
    replaced_by character varying
)
SERVER pantherdb
OPTIONS (
    schema_name 'panther',
    table_name 'goobo_extract'
);


ALTER FOREIGN TABLE goobo_extract OWNER TO postgres;

--
-- TOC entry 490 (class 1259 OID 1362824218)
-- Name: goobo_parent_child; Type: FOREIGN TABLE; Schema: panther_upl; Owner: postgres; Tablespace: 
--

CREATE FOREIGN TABLE goobo_parent_child (
    parent_go character varying,
    child_go character varying
)
SERVER pantherdb
OPTIONS (
    schema_name 'panther',
    table_name 'goobo_parent_child'
);


ALTER FOREIGN TABLE goobo_parent_child OWNER TO postgres;

--
-- TOC entry 367 (class 1259 OID 17108)
-- Name: identifier; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE identifier (
    identifier_id bigint NOT NULL,
    identifier_type_sid bigint,
    primary_object_id bigint,
    name character varying(4000),
    created_by integer,
    creation_date timestamp without time zone,
    obsoleted_by integer,
    obsolescence_date timestamp without time zone,
    classification_id bigint
);


ALTER TABLE identifier OWNER TO panther_upl;

--
-- TOC entry 368 (class 1259 OID 17114)
-- Name: identifier_type; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE identifier_type (
    identifier_type_sid bigint NOT NULL,
    name character varying(32),
    description character varying(256)
);


ALTER TABLE identifier_type OWNER TO panther_upl;

--
-- TOC entry 369 (class 1259 OID 17117)
-- Name: interpro2common; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE interpro2common (
    interpro_common_id bigint NOT NULL,
    classification_id bigint,
    block_id bigint,
    order_in smallint,
    obsolescence_date timestamp without time zone,
    obsoleted_by integer
);


ALTER TABLE interpro2common OWNER TO panther_upl;

--
-- TOC entry 370 (class 1259 OID 17120)
-- Name: interpro_curation_priority; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE interpro_curation_priority (
    priority_code character varying(16),
    panther_acc character varying(32),
    release4curation integer
);


ALTER TABLE interpro_curation_priority OWNER TO panther_upl;

--
-- TOC entry 371 (class 1259 OID 17123)
-- Name: keyword_family_mapping; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE keyword_family_mapping (
    keyword character varying(4000),
    upper_keyword character varying(4000),
    keyword_type_sid integer,
    family_acc character varying(32),
    classification_version_sid integer
);


ALTER TABLE keyword_family_mapping OWNER TO panther_upl;

--
-- TOC entry 372 (class 1259 OID 17129)
-- Name: keyword_type; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE keyword_type (
    keyword_type_sid integer,
    type character varying(32),
    description character varying(64)
);


ALTER TABLE keyword_type OWNER TO panther_upl;

--
-- TOC entry 373 (class 1259 OID 17132)
-- Name: log_table; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE log_table (
    pub_id character varying(32)
);


ALTER TABLE log_table OWNER TO panther_upl;

--
-- TOC entry 374 (class 1259 OID 17135)
-- Name: most_specific_category; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE most_specific_category (
    subfamily_id bigint,
    subfamily_acc character varying(32),
    subfamily_name character varying(256),
    category_id bigint,
    category_acc character varying(32),
    category_name character varying(256),
    classification_version_sid integer
);


ALTER TABLE most_specific_category OWNER TO panther_upl;

--
-- TOC entry 375 (class 1259 OID 17141)
-- Name: msa_detail; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE msa_detail (
    msa_id bigint NOT NULL,
    classification_id bigint,
    msa_text text
);


ALTER TABLE msa_detail OWNER TO panther_upl;

--
-- TOC entry 377 (class 1259 OID 17150)
-- Name: node_name; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE node_name (
    node_name_id bigint NOT NULL,
    node_id bigint,
    name character varying(32),
    created_by integer,
    creation_date timestamp without time zone,
    obsoleted_by integer,
    obsolescence_date timestamp without time zone
);


ALTER TABLE node_name OWNER TO panther_upl;

--
-- TOC entry 477 (class 1259 OID 1362824015)
-- Name: node_production; Type: FOREIGN TABLE; Schema: panther_upl; Owner: postgres; Tablespace: 
--

CREATE FOREIGN TABLE node_production (
    node_id numeric(38,0),
    accession character varying(32),
    public_id character varying(32),
    classification_version_sid numeric(6,0),
    node_type_id numeric(38,0),
    event_type_id numeric(38,0),
    branch_length numeric(8,4),
    created_by numeric(6,0),
    creation_date timestamp(0) without time zone,
    obsoleted_by numeric(6,0),
    obsolescence_date timestamp(0) without time zone
)
SERVER pantherdb
OPTIONS (
    schema_name 'panther',
    table_name 'node'
);


ALTER FOREIGN TABLE node_production OWNER TO postgres;

--
-- TOC entry 378 (class 1259 OID 17153)
-- Name: node_relationship; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE node_relationship (
    node_relationship_id bigint NOT NULL,
    parent_node_id bigint,
    child_node_id bigint,
    created_by integer,
    creation_date timestamp without time zone,
    obsoleted_by integer,
    obsolescence_date timestamp without time zone
);


ALTER TABLE node_relationship OWNER TO panther_upl;

--
-- TOC entry 379 (class 1259 OID 17156)
-- Name: node_type; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE node_type (
    node_type_id bigint NOT NULL,
    node_type character varying(32)
);


ALTER TABLE node_type OWNER TO panther_upl;

--
-- TOC entry 380 (class 1259 OID 17159)
-- Name: obsolete_cat_subfam; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE obsolete_cat_subfam (
    sf_acc character varying(32),
    cat_acc character varying(32)
);


ALTER TABLE obsolete_cat_subfam OWNER TO panther_upl;

--
-- TOC entry 381 (class 1259 OID 17162)
-- Name: organism; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE organism (
    organism_id bigint NOT NULL,
    organism character varying(128),
    conversion character varying(128),
    short_name character varying(128),
    name character varying(32),
    common_name character varying(32),
    logical_ordering bigint,
    ref_genome character varying(6),
    classification_version_sid integer,
    taxon_id bigint
);


ALTER TABLE organism OWNER TO panther_upl;

SET default_with_oids = true;

--
-- TOC entry 688 (class 1259 OID 1565639167)
-- Name: paint_annotation; Type: TABLE; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE TABLE paint_annotation (
    annotation_id numeric(38,0),
    node_id numeric(38,0),
    classification_id numeric(38,0),
    annotation_type_id numeric(38,0),
    created_by numeric(6,0),
    creation_date timestamp(0) without time zone,
    obsoleted_by numeric(6,0),
    obsolescence_date timestamp(0) without time zone
);


ALTER TABLE paint_annotation OWNER TO panther_isp;

--
-- TOC entry 676 (class 1259 OID 1526117349)
-- Name: paint_annotation_forward_tracking; Type: TABLE; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE TABLE paint_annotation_forward_tracking (
    old_annotation_id numeric(38,0),
    new_annotation_id numeric(38,0),
    old_node_id numeric(38,0),
    new_node_id numeric(38,0),
    classification_id numeric(38,0),
    annotation_type_id numeric(38,0),
    created_by numeric(6,0),
    creation_date timestamp(0) without time zone,
    obsoleted_by numeric(6,0),
    obsolescence_date timestamp(0) without time zone
);


ALTER TABLE paint_annotation_forward_tracking OWNER TO panther_isp;

--
-- TOC entry 675 (class 1259 OID 1526093119)
-- Name: paint_annotation_new_v12; Type: TABLE; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE TABLE paint_annotation_new_v12 (
    annotation_id numeric(38,0),
    node_id numeric(38,0),
    classification_id numeric(38,0),
    annotation_type_id numeric(38,0),
    created_by numeric(6,0),
    creation_date timestamp(0) without time zone,
    obsoleted_by numeric(6,0),
    obsolescence_date timestamp(0) without time zone
);


ALTER TABLE paint_annotation_new_v12 OWNER TO panther_isp;

--
-- TOC entry 474 (class 1259 OID 1362798403)
-- Name: paint_annotation_old; Type: TABLE; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE TABLE paint_annotation_old (
    annotation_id numeric(38,0),
    node_id numeric(38,0),
    classification_id numeric(38,0),
    annotation_type_id numeric(38,0),
    created_by numeric(6,0),
    creation_date timestamp(0) without time zone,
    obsoleted_by numeric(6,0),
    obsolescence_date timestamp(0) without time zone
);


ALTER TABLE paint_annotation_old OWNER TO panther_isp;

--
-- TOC entry 476 (class 1259 OID 1362798423)
-- Name: paint_annotation_qualifier; Type: TABLE; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE TABLE paint_annotation_qualifier (
    annotation_qualifier_id numeric(38,0),
    annotation_id numeric(38,0),
    qualifier_id numeric(38,0)
);


ALTER TABLE paint_annotation_qualifier OWNER TO panther_isp;

--
-- TOC entry 682 (class 1259 OID 1538022704)
-- Name: paint_annotation_qualifier_new_v12; Type: TABLE; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE TABLE paint_annotation_qualifier_new_v12 (
    annotation_qualifier_id numeric(38,0),
    annotation_id numeric(38,0),
    qualifier_id numeric(38,0)
);


ALTER TABLE paint_annotation_qualifier_new_v12 OWNER TO panther_isp;

SET default_with_oids = false;

--
-- TOC entry 475 (class 1259 OID 1362798409)
-- Name: paint_evidence; Type: TABLE; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE TABLE paint_evidence (
    evidence_id bigint,
    evidence_type_sid bigint,
    classification_id bigint,
    primary_object_id bigint,
    evidence character varying(1000),
    is_editable integer,
    created_by character varying(64),
    creation_date timestamp without time zone,
    obsoleted_by character varying(64),
    obsolescence_date timestamp without time zone,
    updated_by character varying(64),
    update_date timestamp without time zone,
    pathway_curation_id bigint,
    confidence_code_sid integer,
    annotation_id bigint,
    protein_classification_id bigint
);


ALTER TABLE paint_evidence OWNER TO panther_isp;

--
-- TOC entry 678 (class 1259 OID 1526168261)
-- Name: paint_evidence_new_v12; Type: TABLE; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE TABLE paint_evidence_new_v12 (
    evidence_id bigint,
    evidence_type_sid bigint,
    classification_id bigint,
    primary_object_id bigint,
    evidence character varying(1000),
    is_editable integer,
    created_by character varying(64),
    creation_date timestamp without time zone,
    obsoleted_by character varying(64),
    obsolescence_date timestamp without time zone,
    updated_by character varying(64),
    update_date timestamp without time zone,
    pathway_curation_id bigint,
    confidence_code_sid integer,
    annotation_id bigint,
    protein_classification_id bigint
);


ALTER TABLE paint_evidence_new_v12 OWNER TO panther_isp;

--
-- TOC entry 689 (class 1259 OID 1565664349)
-- Name: paint_evidence_old; Type: TABLE; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE TABLE paint_evidence_old (
    evidence_id bigint,
    evidence_type_sid bigint,
    classification_id bigint,
    primary_object_id bigint,
    evidence character varying(1000),
    is_editable integer,
    created_by character varying(64),
    creation_date timestamp without time zone,
    obsoleted_by character varying(64),
    obsolescence_date timestamp without time zone,
    updated_by character varying(64),
    update_date timestamp without time zone,
    pathway_curation_id bigint,
    confidence_code_sid integer,
    annotation_id bigint,
    protein_classification_id bigint
);


ALTER TABLE paint_evidence_old OWNER TO panther_isp;

--
-- TOC entry 382 (class 1259 OID 17165)
-- Name: panther_to_interpro; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE panther_to_interpro (
    panther_version character varying(64),
    panther_acc character varying(32),
    interpro_version character varying(64),
    interpro_acc character varying(32),
    relationship_type character varying(32),
    panther_cnt bigint,
    interpro_cnt bigint,
    overlap bigint,
    perc_overlap_panther numeric(8,2),
    perc_overlap_interpro numeric(8,2)
);


ALTER TABLE panther_to_interpro OWNER TO panther_upl;

--
-- TOC entry 383 (class 1259 OID 17168)
-- Name: pathway_category_book_visited; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE pathway_category_book_visited (
    pathway_acc character varying(32) NOT NULL,
    category_acc character varying(32) NOT NULL,
    book_acc character varying(32) NOT NULL
);


ALTER TABLE pathway_category_book_visited OWNER TO panther_upl;

--
-- TOC entry 384 (class 1259 OID 17171)
-- Name: pathway_category_info; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE pathway_category_info (
    classification_relationship_id bigint,
    pathway_acc character varying(32),
    pathway_name character varying(256),
    pathway_def character varying(100),
    cat_acc character varying(32),
    cat_name character varying(256),
    cat_def character varying(1000),
    classification_version_sid integer
);


ALTER TABLE pathway_category_info OWNER TO panther_upl;

--
-- TOC entry 385 (class 1259 OID 17177)
-- Name: pathway_category_relation; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE pathway_category_relation (
    pathway_category_relation_id bigint NOT NULL,
    upstream_pathway_category_id bigint,
    downstream_pathway_category_id bigint,
    relationship_type_sid integer,
    created_by integer,
    creation_date timestamp without time zone,
    obsoleted_by integer,
    obsolescence_date timestamp without time zone
);


ALTER TABLE pathway_category_relation OWNER TO panther_upl;

--
-- TOC entry 386 (class 1259 OID 17180)
-- Name: pathway_curation; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE pathway_curation (
    pathway_curation_id bigint NOT NULL,
    classification_relationship_id bigint,
    classification_id bigint,
    protein_id bigint,
    confidence_code_sid integer,
    created_by integer,
    creation_date timestamp without time zone,
    obsoleted_by integer,
    obsolescence_date timestamp without time zone
);


ALTER TABLE pathway_curation OWNER TO panther_upl;

--
-- TOC entry 387 (class 1259 OID 17183)
-- Name: pathway_keyword_search; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE pathway_keyword_search (
    keyword character varying(4000),
    upper_keyword character varying(4000),
    keyword_type_sid bigint,
    classification_version_sid bigint,
    fam_acc character varying(16),
    fam_name character varying(256)
);


ALTER TABLE pathway_keyword_search OWNER TO panther_upl;

--
-- TOC entry 388 (class 1259 OID 17189)
-- Name: pathway_keyword_search_10; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE pathway_keyword_search_10 (
    keyword character varying(2000),
    upper_keyword character varying(2000),
    keyword_type_sid bigint,
    classification_version_sid bigint,
    fam_acc character varying(7),
    fam_name character varying(256)
);


ALTER TABLE pathway_keyword_search_10 OWNER TO panther_upl;

--
-- TOC entry 389 (class 1259 OID 17195)
-- Name: pathway_keyword_search_11; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE pathway_keyword_search_11 (
    keyword character varying(2000),
    upper_keyword character varying(2000),
    keyword_type_sid bigint,
    classification_version_sid bigint,
    fam_acc character varying(7),
    fam_name character varying(256)
);


ALTER TABLE pathway_keyword_search_11 OWNER TO panther_upl;

--
-- TOC entry 390 (class 1259 OID 17201)
-- Name: pathway_xmlfile_lookup; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE pathway_xmlfile_lookup (
    pathway_accession character varying(32),
    pathway_xmlfile_name character varying(128)
);


ALTER TABLE pathway_xmlfile_lookup OWNER TO panther_upl;

--
-- TOC entry 391 (class 1259 OID 17204)
-- Name: pc_qualifier; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE pc_qualifier (
    pc_qualifier_id bigint NOT NULL,
    protein_classification_id bigint,
    qualifier_id bigint
);


ALTER TABLE pc_qualifier OWNER TO panther_upl;

--
-- TOC entry 392 (class 1259 OID 17207)
-- Name: previous_upl_info; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE previous_upl_info (
    current_upl_sequence_id bigint,
    current_upl_sequence_acc character varying(32),
    previous_upl_sequence_id bigint,
    previous_upl_sequence_acc character varying(32),
    subfamily_id bigint,
    current_upl_version_sid integer
);


ALTER TABLE previous_upl_info OWNER TO panther_upl;

--
-- TOC entry 393 (class 1259 OID 17210)
-- Name: prot_temp_sixone; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE prot_temp_sixone (
    protein_id bigint,
    protein_ext_id character varying(32),
    protein_ext_acc character varying(32),
    classification_id bigint
);


ALTER TABLE prot_temp_sixone OWNER TO panther_upl;

--
-- TOC entry 394 (class 1259 OID 17213)
-- Name: protein; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE protein (
    protein_id bigint NOT NULL,
    source_id bigint,
    primary_ext_id character varying(128),
    primary_ext_acc character varying(128),
    created_by integer,
    creation_date timestamp without time zone,
    obsoleted_by integer,
    obsolescence_date timestamp without time zone,
    classification_version_sid integer,
    ext_uid character varying(32),
    is_fragment integer
);


ALTER TABLE protein OWNER TO panther_upl;

--
-- TOC entry 395 (class 1259 OID 17216)
-- Name: protein_classification; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE protein_classification (
    protein_classification_id bigint NOT NULL,
    protein_id bigint,
    classification_id bigint,
    created_by integer,
    creation_date timestamp without time zone,
    obsoleted_by integer,
    obsolescence_date timestamp without time zone
);


ALTER TABLE protein_classification OWNER TO panther_upl;

--
-- TOC entry 396 (class 1259 OID 17219)
-- Name: protein_info; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE protein_info (
    protein_id bigint,
    primary_ext_acc character varying(32),
    primary_ext_id character varying(32),
    definition character varying(4000),
    classification_version_sid integer
);


ALTER TABLE protein_info OWNER TO panther_upl;

--
-- TOC entry 397 (class 1259 OID 17225)
-- Name: protein_mapping; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE protein_mapping (
    old_protein_id bigint,
    new_protein_id bigint
);


ALTER TABLE protein_mapping OWNER TO panther_upl;

--
-- TOC entry 398 (class 1259 OID 17228)
-- Name: protein_node; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE protein_node (
    protein_node_id bigint NOT NULL,
    protein_id bigint,
    node_id bigint,
    created_by integer,
    creation_date timestamp without time zone,
    obsoleted_by integer,
    obsolescence_date timestamp without time zone
);


ALTER TABLE protein_node OWNER TO panther_upl;

--
-- TOC entry 399 (class 1259 OID 17231)
-- Name: protein_source; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE protein_source (
    source_id bigint,
    name character varying(64),
    organism_id bigint,
    database character varying(64),
    created_by integer,
    creation_date timestamp without time zone,
    obsoleted_by integer,
    obsolescence_date timestamp without time zone
);


ALTER TABLE protein_source OWNER TO panther_upl;

--
-- TOC entry 401 (class 1259 OID 17237)
-- Name: relationship_type; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE relationship_type (
    relationship_type_sid integer NOT NULL,
    name character varying(64),
    description character varying(256)
);


ALTER TABLE relationship_type OWNER TO panther_upl;

--
-- TOC entry 402 (class 1259 OID 17240)
-- Name: score; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE score (
    score_id bigint NOT NULL,
    score_type_sid integer,
    feature_id bigint,
    value numeric,
    created_by integer,
    creation_date timestamp without time zone,
    obsoleted_by integer,
    obsolescence_date timestamp without time zone
);


ALTER TABLE score OWNER TO panther_upl;

--
-- TOC entry 403 (class 1259 OID 17243)
-- Name: score_type; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE score_type (
    score_type_sid integer NOT NULL,
    name character varying(32),
    is_primary integer
);


ALTER TABLE score_type OWNER TO panther_upl;

--
-- TOC entry 404 (class 1259 OID 17246)
-- Name: seq_info; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE seq_info (
    accession character varying(32),
    definition character varying(4000),
    function character varying(2000),
    keyword character varying(1000),
    similarity character varying(512),
    spacc character varying(256)
);


ALTER TABLE seq_info OWNER TO panther_upl;

--
-- TOC entry 405 (class 1259 OID 17252)
-- Name: sequence_mapto_prev_version; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE sequence_mapto_prev_version (
    current_upl_sequence_id bigint,
    current_upl_sequence_acc character varying(32),
    previous_upl_sequence_id bigint,
    previous_upl_sequence_acc character varying(32)
);


ALTER TABLE sequence_mapto_prev_version OWNER TO panther_upl;

--
-- TOC entry 406 (class 1259 OID 17255)
-- Name: subfam_category; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE subfam_category (
    subfam_acc character varying(32),
    subfam_name character varying(256),
    category_acc character varying(32)
);


ALTER TABLE subfam_category OWNER TO panther_upl;

--
-- TOC entry 407 (class 1259 OID 17258)
-- Name: subfam_category_hierarchy; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE subfam_category_hierarchy (
    subfam_acc character varying(32),
    subfam_name character varying(256),
    level1_cat_acc character varying(32),
    level1_cat_name character varying(256),
    level2_cat_acc character varying(32),
    level2_cat_name character varying(256),
    level3_cat_acc character varying(32),
    level3_cat_name character varying(256)
);


ALTER TABLE subfam_category_hierarchy OWNER TO panther_upl;

--
-- TOC entry 408 (class 1259 OID 17264)
-- Name: subfam_seq_info; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE subfam_seq_info (
    accession character varying(32),
    evidence character varying(1000),
    xlink character varying(4000),
    organism character varying(256),
    last_comment character varying(1000)
);


ALTER TABLE subfam_seq_info OWNER TO panther_upl;

--
-- TOC entry 409 (class 1259 OID 17270)
-- Name: subfam_seq_relation; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE subfam_seq_relation (
    subfam_acc character varying(32),
    seq_acc character varying(32)
);


ALTER TABLE subfam_seq_relation OWNER TO panther_upl;

--
-- TOC entry 410 (class 1259 OID 17273)
-- Name: subfamily_keyword; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE subfamily_keyword (
    subfamily_id bigint,
    subfamily_acc character varying(32),
    keywords character varying(4000)
);


ALTER TABLE subfamily_keyword OWNER TO panther_upl;

--
-- TOC entry 411 (class 1259 OID 17279)
-- Name: subfamily_organism; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE subfamily_organism (
    subfamily_id bigint,
    subfamily_acc character varying(32),
    organisms character varying(2000)
);


ALTER TABLE subfamily_organism OWNER TO panther_upl;

--
-- TOC entry 412 (class 1259 OID 17285)
-- Name: subfamily_reorder; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE subfamily_reorder (
    old_sf_version character varying(32),
    old_sf_classification_id bigint,
    old_sf_accession character varying(32),
    new_sf_version character varying(32),
    new_sf_classification_id bigint,
    new_sf_accession character varying(32),
    reorder_date timestamp without time zone
);


ALTER TABLE subfamily_reorder OWNER TO panther_upl;

--
-- TOC entry 413 (class 1259 OID 17288)
-- Name: taxonomy; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE taxonomy (
    taxonomy_id bigint,
    kingdom character varying(4),
    scientific_name character varying(128),
    common_name character varying(128),
    taxon_synonym character varying(128)
);


ALTER TABLE taxonomy OWNER TO panther_upl;

--
-- TOC entry 414 (class 1259 OID 17291)
-- Name: temp; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE temp (
    pathway_id bigint,
    pathway_acc character varying(32),
    pathway_name character varying(256),
    comp_id bigint,
    comp_acc character varying(32),
    comp_name character varying(256)
);


ALTER TABLE temp OWNER TO panther_upl;

--
-- TOC entry 415 (class 1259 OID 17297)
-- Name: temp_cat_level1; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE temp_cat_level1 (
    level1_id bigint
);


ALTER TABLE temp_cat_level1 OWNER TO panther_upl;

--
-- TOC entry 416 (class 1259 OID 17300)
-- Name: temp_category_relation_only; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE temp_category_relation_only (
    parent_classification_id bigint,
    parent_acc character varying(128),
    child_classification_id bigint,
    child_acc character varying(32)
);


ALTER TABLE temp_category_relation_only OWNER TO panther_upl;

--
-- TOC entry 417 (class 1259 OID 17303)
-- Name: temp_cats; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE temp_cats (
    cat_id bigint,
    cat_name character varying(256),
    cat_acc character varying(132)
);


ALTER TABLE temp_cats OWNER TO panther_upl;

--
-- TOC entry 418 (class 1259 OID 17306)
-- Name: temp_common_annotation_block; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE temp_common_annotation_block (
    ann_id character varying(7),
    name character varying(50),
    text character varying(4000)
);


ALTER TABLE temp_common_annotation_block OWNER TO panther_upl;

--
-- TOC entry 419 (class 1259 OID 17312)
-- Name: temp_family_category; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE temp_family_category (
    family_acc character varying(9),
    category_acc character varying(32)
);


ALTER TABLE temp_family_category OWNER TO panther_upl;

--
-- TOC entry 420 (class 1259 OID 17315)
-- Name: temp_level1; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE temp_level1 (
    level1_id bigint,
    level1_name character varying(256),
    level1_accession character varying(32)
);


ALTER TABLE temp_level1 OWNER TO panther_upl;

--
-- TOC entry 421 (class 1259 OID 17318)
-- Name: temp_level1_level2; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE temp_level1_level2 (
    level1_id bigint,
    level1_name character varying(256),
    level1_accession character varying(32),
    level2_id bigint,
    level2_name character varying(256),
    level2_accession character varying(32)
);


ALTER TABLE temp_level1_level2 OWNER TO panther_upl;

--
-- TOC entry 422 (class 1259 OID 17324)
-- Name: temp_level1_level2_level3; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE temp_level1_level2_level3 (
    level1_id bigint,
    level1_name character varying(256),
    level1_accession character varying(32),
    level2_id bigint,
    level2_name character varying(256),
    level2_accession character varying(32),
    level3_id bigint,
    level3_name character varying(256),
    level3_accession character varying(32)
);


ALTER TABLE temp_level1_level2_level3 OWNER TO panther_upl;

--
-- TOC entry 423 (class 1259 OID 17330)
-- Name: temp_pathway_association; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE temp_pathway_association (
    pathway_id bigint,
    pathway_acc character varying(32),
    pathway_name character varying(128),
    pathway_long_name character varying(256),
    pathwaycomp_id bigint,
    pathwaycomp_acc character varying(32),
    pathwaycomp_name character varying(128),
    pathwaycomp_long_name character varying(128),
    confidence_code_sid bigint,
    pathway_curation_id bigint,
    protein_id bigint,
    protein_ext_id character varying(32),
    protein_ext_acc character varying(32),
    sf_id bigint
);


ALTER TABLE temp_pathway_association OWNER TO panther_upl;

--
-- TOC entry 424 (class 1259 OID 17336)
-- Name: temp_sf_reorder; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE temp_sf_reorder (
    old_sf_accession character varying(32),
    new_sf_accession character varying(32)
);


ALTER TABLE temp_sf_reorder OWNER TO panther_upl;

--
-- TOC entry 425 (class 1259 OID 17339)
-- Name: temp_subfamily_category; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE temp_subfamily_category (
    parent_classification_id bigint,
    parent_acc character varying(32),
    child_classification_id bigint,
    child_acc character varying(32)
);


ALTER TABLE temp_subfamily_category OWNER TO panther_upl;

--
-- TOC entry 426 (class 1259 OID 17342)
-- Name: temp_subfamily_category_count; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE temp_subfamily_category_count (
    family_acc character varying(9),
    parent_acc character varying(32),
    num bigint
);


ALTER TABLE temp_subfamily_category_count OWNER TO panther_upl;

--
-- TOC entry 427 (class 1259 OID 17345)
-- Name: temp_uniprot_score; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE temp_uniprot_score (
    protein_classification_id bigint,
    feature_id bigint,
    classification_id bigint,
    protein_id bigint,
    raw_score integer,
    evalue character varying(10)
);


ALTER TABLE temp_uniprot_score OWNER TO panther_upl;

--
-- TOC entry 428 (class 1259 OID 17348)
-- Name: test_new_books; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE test_new_books (
    accession character varying(32)
);


ALTER TABLE test_new_books OWNER TO panther_upl;

--
-- TOC entry 429 (class 1259 OID 17351)
-- Name: tmp; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE tmp (
    parent_classification_id bigint,
    child_classification_id bigint,
    rank integer
);


ALTER TABLE tmp OWNER TO panther_upl;

--
-- TOC entry 430 (class 1259 OID 17354)
-- Name: tree_detail; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE tree_detail (
    tree_id bigint NOT NULL,
    classification_id bigint,
    tree_text text,
    created_by integer,
    creation_date timestamp without time zone,
    obsoleted_by integer,
    obsolescence_date timestamp without time zone
);


ALTER TABLE tree_detail OWNER TO panther_upl;

--
-- TOC entry 438 (class 1259 OID 702252403)
-- Name: uids; Type: SEQUENCE; Schema: panther_upl; Owner: panther_upl
--

CREATE SEQUENCE uids
    START WITH 217083006
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 999999999999999999
    CACHE 1;


ALTER TABLE uids OWNER TO panther_upl;

--
-- TOC entry 431 (class 1259 OID 17360)
-- Name: upl_book_visited; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE upl_book_visited (
    cls_acc character varying(32),
    user_id integer
);


ALTER TABLE upl_book_visited OWNER TO panther_upl;

--
-- TOC entry 432 (class 1259 OID 17363)
-- Name: users; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE users (
    user_id bigint NOT NULL,
    name character varying(64),
    login_name character varying(32),
    password character varying(32),
    email character varying(64),
    address character varying(128),
    group_name character varying(32),
    privilege character varying(128),
    privilege_rank integer,
    ssn character varying(16),
    phone character varying(128),
    title character varying(100),
    is_approved integer,
    org_from character varying(100),
    creation_date timestamp without time zone
);


ALTER TABLE users OWNER TO panther_upl;

--
-- TOC entry 433 (class 1259 OID 17369)
-- Name: valid_organism; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE valid_organism (
    organism character varying(128)
);


ALTER TABLE valid_organism OWNER TO panther_upl;

--
-- TOC entry 434 (class 1259 OID 17372)
-- Name: view_protein_classification; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE view_protein_classification (
    classification_version_sid integer,
    classification_id bigint,
    accession character varying(32),
    name character varying(256),
    protein_classification_id bigint,
    protein_id bigint,
    primary_ext_acc character varying(32),
    primary_ext_id character varying(32),
    source_id bigint
);


ALTER TABLE view_protein_classification OWNER TO panther_upl;

--
-- TOC entry 435 (class 1259 OID 17375)
-- Name: view_protein_classification_1; Type: TABLE; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE TABLE view_protein_classification_1 (
    classification_version_sid integer,
    classification_id bigint,
    accession character varying(32),
    name character varying(256),
    protein_classification_id bigint,
    protein_id bigint,
    primary_ext_acc character varying(32),
    primary_ext_id character varying(32),
    source_id bigint
);


ALTER TABLE view_protein_classification_1 OWNER TO panther_upl;

--
-- TOC entry 4762 (class 2606 OID 17709)
-- Name: annotation_pkey; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY annotation
    ADD CONSTRAINT annotation_pkey PRIMARY KEY (annotation_id);


--
-- TOC entry 4766 (class 2606 OID 17739)
-- Name: annotation_type_pkey; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY annotation_type
    ADD CONSTRAINT annotation_type_pkey PRIMARY KEY (annotation_type_id);


--
-- TOC entry 4791 (class 2606 OID 17713)
-- Name: curation_status_pk; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY curation_status
    ADD CONSTRAINT curation_status_pk PRIMARY KEY (curation_status_id);


--
-- TOC entry 4890 (class 2606 OID 1526167858)
-- Name: curation_status_pk1; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY curation_status_new_v12
    ADD CONSTRAINT curation_status_pk1 PRIMARY KEY (curation_status_id);


--
-- TOC entry 4795 (class 2606 OID 17743)
-- Name: event_type_pkey; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY event_type
    ADD CONSTRAINT event_type_pkey PRIMARY KEY (event_type_id);


--
-- TOC entry 4807 (class 2606 OID 17705)
-- Name: gene_node_pkey; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY gene_node
    ADD CONSTRAINT gene_node_pkey PRIMARY KEY (gene_node_id);


--
-- TOC entry 4829 (class 2606 OID 17755)
-- Name: node_name_pkey; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY node_name
    ADD CONSTRAINT node_name_pkey PRIMARY KEY (node_name_id);


--
-- TOC entry 4831 (class 2606 OID 17699)
-- Name: node_relationship_pkey; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY node_relationship
    ADD CONSTRAINT node_relationship_pkey PRIMARY KEY (node_relationship_id);


--
-- TOC entry 4833 (class 2606 OID 17763)
-- Name: node_type_pkey; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY node_type
    ADD CONSTRAINT node_type_pkey PRIMARY KEY (node_type_id);


--
-- TOC entry 4837 (class 2606 OID 17759)
-- Name: pathway_category_book_visited_pkey; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY pathway_category_book_visited
    ADD CONSTRAINT pathway_category_book_visited_pkey PRIMARY KEY (pathway_acc, category_acc, book_acc);


--
-- TOC entry 4843 (class 2606 OID 17769)
-- Name: pc_qualifier_pkey; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY pc_qualifier
    ADD CONSTRAINT pc_qualifier_pkey PRIMARY KEY (pc_qualifier_id);


--
-- TOC entry 4755 (class 2606 OID 17719)
-- Name: pk_abstract; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY abstract
    ADD CONSTRAINT pk_abstract PRIMARY KEY (abstract_id);


--
-- TOC entry 4757 (class 2606 OID 17729)
-- Name: pk_abstract_type; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY abstract_type
    ADD CONSTRAINT pk_abstract_type PRIMARY KEY (abstract_type_sid);


--
-- TOC entry 4764 (class 2606 OID 17717)
-- Name: pk_annotation_qualifier; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY annotation_qualifier
    ADD CONSTRAINT pk_annotation_qualifier PRIMARY KEY (annotation_qualifier_id);


--
-- TOC entry 4768 (class 2606 OID 17733)
-- Name: pk_bio_sequence; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY bio_sequence
    ADD CONSTRAINT pk_bio_sequence PRIMARY KEY (seq_id);


--
-- TOC entry 4772 (class 2606 OID 17707)
-- Name: pk_classification; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY classification
    ADD CONSTRAINT pk_classification PRIMARY KEY (classification_id);


--
-- TOC entry 4777 (class 2606 OID 17701)
-- Name: pk_classification_relationship; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY classification_relationship
    ADD CONSTRAINT pk_classification_relationship PRIMARY KEY (classification_relationship_id);


--
-- TOC entry 4779 (class 2606 OID 17737)
-- Name: pk_classification_term_type; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY classification_term_type
    ADD CONSTRAINT pk_classification_term_type PRIMARY KEY (term_type_sid);


--
-- TOC entry 4781 (class 2606 OID 17735)
-- Name: pk_classification_type; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY classification_type
    ADD CONSTRAINT pk_classification_type PRIMARY KEY (classification_type_sid);


--
-- TOC entry 4783 (class 2606 OID 17723)
-- Name: pk_classification_version; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY classification_version
    ADD CONSTRAINT pk_classification_version PRIMARY KEY (classification_version_sid);


--
-- TOC entry 4787 (class 2606 OID 17721)
-- Name: pk_com_anno_block; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY common_annotation_block
    ADD CONSTRAINT pk_com_anno_block PRIMARY KEY (block_id);


--
-- TOC entry 4785 (class 2606 OID 17711)
-- Name: pk_comment; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY comments
    ADD CONSTRAINT pk_comment PRIMARY KEY (comment_id);


--
-- TOC entry 4789 (class 2606 OID 17745)
-- Name: pk_confidence_code; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY confidence_code
    ADD CONSTRAINT pk_confidence_code PRIMARY KEY (confidence_code_sid);


--
-- TOC entry 4793 (class 2606 OID 17741)
-- Name: pk_curation_status_type; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY curation_status_type
    ADD CONSTRAINT pk_curation_status_type PRIMARY KEY (status_type_sid);


--
-- TOC entry 4797 (class 2606 OID 17747)
-- Name: pk_evidence_type; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY evidence_type
    ADD CONSTRAINT pk_evidence_type PRIMARY KEY (evidence_type_sid);


--
-- TOC entry 4799 (class 2606 OID 17749)
-- Name: pk_feature_type; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY feature_type
    ADD CONSTRAINT pk_feature_type PRIMARY KEY (feature_type_sid);


--
-- TOC entry 4816 (class 2606 OID 17848)
-- Name: pk_identifier; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY identifier
    ADD CONSTRAINT pk_identifier PRIMARY KEY (identifier_id);


--
-- TOC entry 4818 (class 2606 OID 17751)
-- Name: pk_identifier_type; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY identifier_type
    ADD CONSTRAINT pk_identifier_type PRIMARY KEY (identifier_type_sid);


--
-- TOC entry 4822 (class 2606 OID 17753)
-- Name: pk_msa_detail; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY msa_detail
    ADD CONSTRAINT pk_msa_detail PRIMARY KEY (msa_id);


--
-- TOC entry 4827 (class 2606 OID 17703)
-- Name: pk_node; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY node
    ADD CONSTRAINT pk_node PRIMARY KEY (node_id);


--
-- TOC entry 4835 (class 2606 OID 17757)
-- Name: pk_organism; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY organism
    ADD CONSTRAINT pk_organism PRIMARY KEY (organism_id);


--
-- TOC entry 4839 (class 2606 OID 17761)
-- Name: pk_path_cat_relation; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY pathway_category_relation
    ADD CONSTRAINT pk_path_cat_relation PRIMARY KEY (pathway_category_relation_id);


--
-- TOC entry 4841 (class 2606 OID 17765)
-- Name: pk_pathway_curation; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY pathway_curation
    ADD CONSTRAINT pk_pathway_curation PRIMARY KEY (pathway_curation_id);


--
-- TOC entry 4847 (class 2606 OID 17767)
-- Name: pk_protein; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY protein
    ADD CONSTRAINT pk_protein PRIMARY KEY (protein_id);


--
-- TOC entry 4849 (class 2606 OID 17771)
-- Name: pk_protein_classification; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY protein_classification
    ADD CONSTRAINT pk_protein_classification PRIMARY KEY (protein_classification_id);


--
-- TOC entry 4855 (class 2606 OID 17777)
-- Name: pk_relationship_type; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY relationship_type
    ADD CONSTRAINT pk_relationship_type PRIMARY KEY (relationship_type_sid);


--
-- TOC entry 4857 (class 2606 OID 17779)
-- Name: pk_score; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY score
    ADD CONSTRAINT pk_score PRIMARY KEY (score_id);


--
-- TOC entry 4859 (class 2606 OID 17781)
-- Name: pk_score_type; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY score_type
    ADD CONSTRAINT pk_score_type PRIMARY KEY (score_type_sid);


--
-- TOC entry 4861 (class 2606 OID 17783)
-- Name: pk_tree_detail; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY tree_detail
    ADD CONSTRAINT pk_tree_detail PRIMARY KEY (tree_id);


--
-- TOC entry 4863 (class 2606 OID 17785)
-- Name: pk_user_group; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT pk_user_group PRIMARY KEY (user_id);


--
-- TOC entry 4820 (class 2606 OID 17715)
-- Name: pkp_interpro2common; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY interpro2common
    ADD CONSTRAINT pkp_interpro2common PRIMARY KEY (interpro_common_id);


--
-- TOC entry 4851 (class 2606 OID 17773)
-- Name: protein_node_pkey; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY protein_node
    ADD CONSTRAINT protein_node_pkey PRIMARY KEY (protein_node_id);


--
-- TOC entry 4853 (class 2606 OID 17775)
-- Name: qualifier_pkey; Type: CONSTRAINT; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

ALTER TABLE ONLY qualifier
    ADD CONSTRAINT qualifier_pkey PRIMARY KEY (qualifier_id);


--
-- TOC entry 4758 (class 1259 OID 1374929388)
-- Name: IDX_CLASSIFICATION_ID; Type: INDEX; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE INDEX "IDX_CLASSIFICATION_ID" ON annotation USING btree (classification_id);


--
-- TOC entry 4912 (class 1259 OID 1565639170)
-- Name: IDX_CLASSIFICATION_ID_10; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX "IDX_CLASSIFICATION_ID_10" ON paint_annotation USING btree (classification_id);


--
-- TOC entry 4873 (class 1259 OID 1362824185)
-- Name: IDX_CLASSIFICATION_ID_3; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX "IDX_CLASSIFICATION_ID_3" ON go_annotation_old USING btree (classification_id);


--
-- TOC entry 4864 (class 1259 OID 1362798406)
-- Name: IDX_CLASSIFICATION_ID_4; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX "IDX_CLASSIFICATION_ID_4" ON paint_annotation_old USING btree (classification_id);


--
-- TOC entry 4881 (class 1259 OID 1526093122)
-- Name: IDX_CLASSIFICATION_ID_5; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX "IDX_CLASSIFICATION_ID_5" ON paint_annotation_new_v12 USING btree (classification_id);


--
-- TOC entry 4896 (class 1259 OID 1526168542)
-- Name: IDX_CLASSIFICATION_ID_6; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX "IDX_CLASSIFICATION_ID_6" ON go_annotation USING btree (classification_id);


--
-- TOC entry 4904 (class 1259 OID 1541580901)
-- Name: IDX_CLASSIFICATION_ID_7; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX "IDX_CLASSIFICATION_ID_7" ON go_annotation_new_v12 USING btree (classification_id);


--
-- TOC entry 4884 (class 1259 OID 1526117352)
-- Name: IDX_CLASSIFICATION_ID_8; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX "IDX_CLASSIFICATION_ID_8" ON paint_annotation_forward_tracking USING btree (classification_id);


--
-- TOC entry 4803 (class 1259 OID 1406915923)
-- Name: IDX_GENE_NODE_GENE_ID; Type: INDEX; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE INDEX "IDX_GENE_NODE_GENE_ID" ON gene_node USING btree (gene_id);


--
-- TOC entry 4804 (class 1259 OID 1406915924)
-- Name: IDX_GENE_NODE_ID; Type: INDEX; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE UNIQUE INDEX "IDX_GENE_NODE_ID" ON gene_node USING btree (gene_node_id);


--
-- TOC entry 4805 (class 1259 OID 1406915925)
-- Name: IDX_GENE_NODE_NODE_ID; Type: INDEX; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE INDEX "IDX_GENE_NODE_NODE_ID" ON gene_node USING btree (node_id);


--
-- TOC entry 4808 (class 1259 OID 1406915928)
-- Name: IDX_GENE_PROTEIN_GENE_ID; Type: INDEX; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE INDEX "IDX_GENE_PROTEIN_GENE_ID" ON gene_protein USING btree (gene_id);


--
-- TOC entry 4809 (class 1259 OID 1406915929)
-- Name: IDX_GENE_PROTEIN_ID; Type: INDEX; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE INDEX "IDX_GENE_PROTEIN_ID" ON gene_protein USING btree (gene_protein_id);


--
-- TOC entry 4810 (class 1259 OID 1406915930)
-- Name: IDX_GENE_PROTEIN_PROTEIN_ID; Type: INDEX; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE INDEX "IDX_GENE_PROTEIN_PROTEIN_ID" ON gene_protein USING btree (protein_id);


--
-- TOC entry 4759 (class 1259 OID 1374929389)
-- Name: IDX_NODE_ID; Type: INDEX; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE INDEX "IDX_NODE_ID" ON annotation USING btree (node_id);


--
-- TOC entry 4885 (class 1259 OID 1526117354)
-- Name: IDX_NODE_ID_10; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX "IDX_NODE_ID_10" ON paint_annotation_forward_tracking USING btree (new_node_id);


--
-- TOC entry 4865 (class 1259 OID 1565639171)
-- Name: IDX_NODE_ID_11; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX "IDX_NODE_ID_11" ON paint_annotation_old USING btree (node_id);


--
-- TOC entry 4874 (class 1259 OID 1362824186)
-- Name: IDX_NODE_ID_3; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX "IDX_NODE_ID_3" ON go_annotation_old USING btree (node_id);


--
-- TOC entry 4866 (class 1259 OID 1362798407)
-- Name: IDX_NODE_ID_4; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX "IDX_NODE_ID_4" ON paint_annotation_old USING btree (node_id);


--
-- TOC entry 4882 (class 1259 OID 1526093123)
-- Name: IDX_NODE_ID_5; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX "IDX_NODE_ID_5" ON paint_annotation_new_v12 USING btree (node_id);


--
-- TOC entry 4897 (class 1259 OID 1526168543)
-- Name: IDX_NODE_ID_6; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX "IDX_NODE_ID_6" ON go_annotation USING btree (node_id);


--
-- TOC entry 4905 (class 1259 OID 1541580902)
-- Name: IDX_NODE_ID_7; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX "IDX_NODE_ID_7" ON go_annotation_new_v12 USING btree (node_id);


--
-- TOC entry 4886 (class 1259 OID 1526117353)
-- Name: IDX_NODE_ID_9; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX "IDX_NODE_ID_9" ON paint_annotation_forward_tracking USING btree (old_node_id);


--
-- TOC entry 4823 (class 1259 OID 1406915931)
-- Name: IDX_NODE_NODE_ID; Type: INDEX; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE UNIQUE INDEX "IDX_NODE_NODE_ID" ON node USING btree (node_id);


--
-- TOC entry 4760 (class 1259 OID 1374929390)
-- Name: PK_ANNOTATION_ID; Type: INDEX; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE UNIQUE INDEX "PK_ANNOTATION_ID" ON annotation USING btree (annotation_id);


--
-- TOC entry 4913 (class 1259 OID 1565639172)
-- Name: PK_ANNOTATION_ID_10; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE UNIQUE INDEX "PK_ANNOTATION_ID_10" ON paint_annotation USING btree (annotation_id);


--
-- TOC entry 4887 (class 1259 OID 1526162778)
-- Name: PK_ANNOTATION_ID_11; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX "PK_ANNOTATION_ID_11" ON paint_annotation_forward_tracking USING btree (old_annotation_id);


--
-- TOC entry 4888 (class 1259 OID 1526117356)
-- Name: PK_ANNOTATION_ID_12; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE UNIQUE INDEX "PK_ANNOTATION_ID_12" ON paint_annotation_forward_tracking USING btree (new_annotation_id);


--
-- TOC entry 4875 (class 1259 OID 1362824187)
-- Name: PK_ANNOTATION_ID_3; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE UNIQUE INDEX "PK_ANNOTATION_ID_3" ON go_annotation_old USING btree (annotation_id);


--
-- TOC entry 4867 (class 1259 OID 1362798408)
-- Name: PK_ANNOTATION_ID_4; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE UNIQUE INDEX "PK_ANNOTATION_ID_4" ON paint_annotation_old USING btree (annotation_id);


--
-- TOC entry 4883 (class 1259 OID 1526093124)
-- Name: PK_ANNOTATION_ID_5; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE UNIQUE INDEX "PK_ANNOTATION_ID_5" ON paint_annotation_new_v12 USING btree (annotation_id);


--
-- TOC entry 4898 (class 1259 OID 1526168544)
-- Name: PK_ANNOTATION_ID_6; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE UNIQUE INDEX "PK_ANNOTATION_ID_6" ON go_annotation USING btree (annotation_id);


--
-- TOC entry 4906 (class 1259 OID 1541580903)
-- Name: PK_ANNOTATION_ID_7; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE UNIQUE INDEX "PK_ANNOTATION_ID_7" ON go_annotation_new_v12 USING btree (annotation_id);


--
-- TOC entry 4876 (class 1259 OID 1362824206)
-- Name: PK_EVIDENCE_3; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE UNIQUE INDEX "PK_EVIDENCE_3" ON go_evidence_old USING btree (evidence_id);


--
-- TOC entry 4868 (class 1259 OID 1362798415)
-- Name: PK_EVIDENCE_4; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE UNIQUE INDEX "PK_EVIDENCE_4" ON paint_evidence USING btree (evidence_id);


--
-- TOC entry 4891 (class 1259 OID 1526168267)
-- Name: PK_EVIDENCE_5; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE UNIQUE INDEX "PK_EVIDENCE_5" ON paint_evidence_new_v12 USING btree (evidence_id);


--
-- TOC entry 4899 (class 1259 OID 1532058338)
-- Name: PK_EVIDENCE_6; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE UNIQUE INDEX "PK_EVIDENCE_6" ON go_evidence USING btree (evidence_id);


--
-- TOC entry 4907 (class 1259 OID 1556463841)
-- Name: PK_EVIDENCE_7; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE UNIQUE INDEX "PK_EVIDENCE_7" ON go_evidence_new_v12 USING btree (evidence_id);


--
-- TOC entry 4914 (class 1259 OID 1565664355)
-- Name: PK_EVIDENCE_8; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE UNIQUE INDEX "PK_EVIDENCE_8" ON paint_evidence_old USING btree (evidence_id);


--
-- TOC entry 4800 (class 1259 OID 1374929392)
-- Name: PK_GENE; Type: INDEX; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE INDEX "PK_GENE" ON gene USING btree (gene_id);


--
-- TOC entry 4769 (class 1259 OID 1374928216)
-- Name: PK_classification; Type: INDEX; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE UNIQUE INDEX "PK_classification" ON classification USING btree (classification_id);


--
-- TOC entry 4770 (class 1259 OID 1374928217)
-- Name: idx_classification_0; Type: INDEX; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE INDEX idx_classification_0 ON classification USING btree (accession);


--
-- TOC entry 4773 (class 1259 OID 1374929375)
-- Name: idx_classification_relation_0; Type: INDEX; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE INDEX idx_classification_relation_0 ON classification_relationship USING btree (parent_classification_id);


--
-- TOC entry 4774 (class 1259 OID 1374929376)
-- Name: idx_classification_relation_1; Type: INDEX; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE INDEX idx_classification_relation_1 ON classification_relationship USING btree (child_classification_id);


--
-- TOC entry 4775 (class 1259 OID 1374929377)
-- Name: idx_classification_relation_2; Type: INDEX; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE INDEX idx_classification_relation_2 ON classification_relationship USING btree (parent_classification_id, child_classification_id);


--
-- TOC entry 4877 (class 1259 OID 1362824207)
-- Name: idx_evidence_0_3; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX idx_evidence_0_3 ON go_evidence_old USING btree (classification_id);


--
-- TOC entry 4869 (class 1259 OID 1362798416)
-- Name: idx_evidence_0_4; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX idx_evidence_0_4 ON paint_evidence USING btree (classification_id);


--
-- TOC entry 4900 (class 1259 OID 1532058339)
-- Name: idx_evidence_0_5; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX idx_evidence_0_5 ON go_evidence USING btree (classification_id);


--
-- TOC entry 4908 (class 1259 OID 1556463842)
-- Name: idx_evidence_0_6; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX idx_evidence_0_6 ON go_evidence_new_v12 USING btree (classification_id);


--
-- TOC entry 4915 (class 1259 OID 1565664356)
-- Name: idx_evidence_0_7; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX idx_evidence_0_7 ON paint_evidence_old USING btree (classification_id);


--
-- TOC entry 4878 (class 1259 OID 1362824208)
-- Name: idx_evidence_1_3; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX idx_evidence_1_3 ON go_evidence_old USING btree (primary_object_id);


--
-- TOC entry 4870 (class 1259 OID 1362798417)
-- Name: idx_evidence_1_4; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX idx_evidence_1_4 ON paint_evidence USING btree (primary_object_id);


--
-- TOC entry 4901 (class 1259 OID 1532058340)
-- Name: idx_evidence_1_5; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX idx_evidence_1_5 ON go_evidence USING btree (primary_object_id);


--
-- TOC entry 4909 (class 1259 OID 1556463843)
-- Name: idx_evidence_1_6; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX idx_evidence_1_6 ON go_evidence_new_v12 USING btree (primary_object_id);


--
-- TOC entry 4916 (class 1259 OID 1565664357)
-- Name: idx_evidence_1_7; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX idx_evidence_1_7 ON paint_evidence_old USING btree (primary_object_id);


--
-- TOC entry 4879 (class 1259 OID 1362824209)
-- Name: idx_evidence_2_3; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX idx_evidence_2_3 ON go_evidence_old USING btree (pathway_curation_id);


--
-- TOC entry 4871 (class 1259 OID 1362798418)
-- Name: idx_evidence_2_4; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX idx_evidence_2_4 ON paint_evidence USING btree (pathway_curation_id);


--
-- TOC entry 4902 (class 1259 OID 1532058341)
-- Name: idx_evidence_2_5; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX idx_evidence_2_5 ON go_evidence USING btree (pathway_curation_id);


--
-- TOC entry 4910 (class 1259 OID 1556463844)
-- Name: idx_evidence_2_6; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX idx_evidence_2_6 ON go_evidence_new_v12 USING btree (pathway_curation_id);


--
-- TOC entry 4917 (class 1259 OID 1565664358)
-- Name: idx_evidence_2_7; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX idx_evidence_2_7 ON paint_evidence_old USING btree (pathway_curation_id);


--
-- TOC entry 4892 (class 1259 OID 1526168268)
-- Name: idx_evidence_3_4; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX idx_evidence_3_4 ON paint_evidence_new_v12 USING btree (classification_id);


--
-- TOC entry 4893 (class 1259 OID 1526168269)
-- Name: idx_evidence_4_4; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX idx_evidence_4_4 ON paint_evidence_new_v12 USING btree (primary_object_id);


--
-- TOC entry 4894 (class 1259 OID 1526168270)
-- Name: idx_evidence_5_4; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX idx_evidence_5_4 ON paint_evidence_new_v12 USING btree (pathway_curation_id);


--
-- TOC entry 4801 (class 1259 OID 1374929393)
-- Name: idx_gene_0; Type: INDEX; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE INDEX idx_gene_0 ON gene USING btree (primary_ext_id);


--
-- TOC entry 4802 (class 1259 OID 1374929394)
-- Name: idx_gene_1; Type: INDEX; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE INDEX idx_gene_1 ON gene USING btree (primary_ext_acc);


--
-- TOC entry 4811 (class 1259 OID 1374928205)
-- Name: idx_identifier_0; Type: INDEX; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE INDEX idx_identifier_0 ON identifier USING btree (identifier_type_sid);


--
-- TOC entry 4812 (class 1259 OID 1374928206)
-- Name: idx_identifier_1; Type: INDEX; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE INDEX idx_identifier_1 ON identifier USING btree (primary_object_id);


--
-- TOC entry 4813 (class 1259 OID 1374928207)
-- Name: idx_identifier_3; Type: INDEX; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE INDEX idx_identifier_3 ON identifier USING btree (classification_id);


--
-- TOC entry 4814 (class 1259 OID 1374928208)
-- Name: idx_identifier_id_group; Type: INDEX; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE INDEX idx_identifier_id_group ON identifier USING btree (primary_object_id, name);


--
-- TOC entry 4880 (class 1259 OID 1362824210)
-- Name: idx_lit_id_group_3; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX idx_lit_id_group_3 ON go_evidence_old USING btree (primary_object_id, evidence_type_sid, evidence);


--
-- TOC entry 4872 (class 1259 OID 1362798419)
-- Name: idx_lit_id_group_4; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX idx_lit_id_group_4 ON paint_evidence USING btree (primary_object_id, evidence_type_sid, evidence);


--
-- TOC entry 4895 (class 1259 OID 1526168271)
-- Name: idx_lit_id_group_5; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX idx_lit_id_group_5 ON paint_evidence_new_v12 USING btree (primary_object_id, evidence_type_sid, evidence);


--
-- TOC entry 4903 (class 1259 OID 1532058342)
-- Name: idx_lit_id_group_6; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX idx_lit_id_group_6 ON go_evidence USING btree (primary_object_id, evidence_type_sid, evidence);


--
-- TOC entry 4911 (class 1259 OID 1556463845)
-- Name: idx_lit_id_group_7; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX idx_lit_id_group_7 ON go_evidence_new_v12 USING btree (primary_object_id, evidence_type_sid, evidence);


--
-- TOC entry 4918 (class 1259 OID 1565664359)
-- Name: idx_lit_id_group_8; Type: INDEX; Schema: panther_upl; Owner: panther_isp; Tablespace: 
--

CREATE INDEX idx_lit_id_group_8 ON paint_evidence_old USING btree (primary_object_id, evidence_type_sid, evidence);


--
-- TOC entry 4824 (class 1259 OID 1406915932)
-- Name: idx_node_accession; Type: INDEX; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE INDEX idx_node_accession ON node USING btree (accession);


--
-- TOC entry 4825 (class 1259 OID 1406915933)
-- Name: idx_node_cls_version; Type: INDEX; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE INDEX idx_node_cls_version ON node USING btree (classification_version_sid);


--
-- TOC entry 4844 (class 1259 OID 781964326)
-- Name: idx_protein_1; Type: INDEX; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE INDEX idx_protein_1 ON protein USING btree (primary_ext_id);


--
-- TOC entry 4845 (class 1259 OID 781964325)
-- Name: idx_protein_2; Type: INDEX; Schema: panther_upl; Owner: panther_upl; Tablespace: 
--

CREATE INDEX idx_protein_2 ON protein USING btree (primary_ext_acc);


--
-- TOC entry 5038 (class 0 OID 0)
-- Dependencies: 7
-- Name: panther_upl; Type: ACL; Schema: -; Owner: panther_upl
--

REVOKE ALL ON SCHEMA panther_upl FROM PUBLIC;
REVOKE ALL ON SCHEMA panther_upl FROM panther_upl;
GRANT ALL ON SCHEMA panther_upl TO panther_upl;
GRANT USAGE ON SCHEMA panther_upl TO panther_users;


--
-- TOC entry 5039 (class 0 OID 0)
-- Dependencies: 749
-- Name: step001_000_load_release_parameters(integer, integer, text); Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON FUNCTION step001_000_load_release_parameters(cls_version_sid integer, cls_type_sid integer, version text) FROM PUBLIC;
REVOKE ALL ON FUNCTION step001_000_load_release_parameters(cls_version_sid integer, cls_type_sid integer, version text) FROM postgres;
GRANT ALL ON FUNCTION step001_000_load_release_parameters(cls_version_sid integer, cls_type_sid integer, version text) TO postgres;
GRANT ALL ON FUNCTION step001_000_load_release_parameters(cls_version_sid integer, cls_type_sid integer, version text) TO PUBLIC;
GRANT ALL ON FUNCTION step001_000_load_release_parameters(cls_version_sid integer, cls_type_sid integer, version text) TO panther_users;


--
-- TOC entry 5040 (class 0 OID 0)
-- Dependencies: 735
-- Name: step002_000_load_classification(integer); Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON FUNCTION step002_000_load_classification(cls_version_sid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION step002_000_load_classification(cls_version_sid integer) FROM postgres;
GRANT ALL ON FUNCTION step002_000_load_classification(cls_version_sid integer) TO postgres;
GRANT ALL ON FUNCTION step002_000_load_classification(cls_version_sid integer) TO PUBLIC;
GRANT ALL ON FUNCTION step002_000_load_classification(cls_version_sid integer) TO panther_users;


--
-- TOC entry 5041 (class 0 OID 0)
-- Dependencies: 750
-- Name: step002_001_load_classification_with_pthr00000(integer); Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON FUNCTION step002_001_load_classification_with_pthr00000(cls_version_sid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION step002_001_load_classification_with_pthr00000(cls_version_sid integer) FROM postgres;
GRANT ALL ON FUNCTION step002_001_load_classification_with_pthr00000(cls_version_sid integer) TO postgres;
GRANT ALL ON FUNCTION step002_001_load_classification_with_pthr00000(cls_version_sid integer) TO PUBLIC;
GRANT ALL ON FUNCTION step002_001_load_classification_with_pthr00000(cls_version_sid integer) TO panther_users;


--
-- TOC entry 5042 (class 0 OID 0)
-- Dependencies: 751
-- Name: step002_002_load_classification_with_goslim(integer); Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON FUNCTION step002_002_load_classification_with_goslim(cls_version_sid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION step002_002_load_classification_with_goslim(cls_version_sid integer) FROM postgres;
GRANT ALL ON FUNCTION step002_002_load_classification_with_goslim(cls_version_sid integer) TO postgres;
GRANT ALL ON FUNCTION step002_002_load_classification_with_goslim(cls_version_sid integer) TO PUBLIC;
GRANT ALL ON FUNCTION step002_002_load_classification_with_goslim(cls_version_sid integer) TO panther_users;


--
-- TOC entry 5043 (class 0 OID 0)
-- Dependencies: 752
-- Name: step002_003_load_classification_with_goslim_root(integer); Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON FUNCTION step002_003_load_classification_with_goslim_root(cls_version_sid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION step002_003_load_classification_with_goslim_root(cls_version_sid integer) FROM postgres;
GRANT ALL ON FUNCTION step002_003_load_classification_with_goslim_root(cls_version_sid integer) TO postgres;
GRANT ALL ON FUNCTION step002_003_load_classification_with_goslim_root(cls_version_sid integer) TO PUBLIC;
GRANT ALL ON FUNCTION step002_003_load_classification_with_goslim_root(cls_version_sid integer) TO panther_users;


--
-- TOC entry 5044 (class 0 OID 0)
-- Dependencies: 737
-- Name: step002_004_load_classification_with_protein_class(integer); Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON FUNCTION step002_004_load_classification_with_protein_class(cls_version_sid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION step002_004_load_classification_with_protein_class(cls_version_sid integer) FROM postgres;
GRANT ALL ON FUNCTION step002_004_load_classification_with_protein_class(cls_version_sid integer) TO postgres;
GRANT ALL ON FUNCTION step002_004_load_classification_with_protein_class(cls_version_sid integer) TO PUBLIC;
GRANT ALL ON FUNCTION step002_004_load_classification_with_protein_class(cls_version_sid integer) TO panther_users;


--
-- TOC entry 5045 (class 0 OID 0)
-- Dependencies: 753
-- Name: step003_000_load_classification_relationship(integer); Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON FUNCTION step003_000_load_classification_relationship(cls_version_sid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION step003_000_load_classification_relationship(cls_version_sid integer) FROM postgres;
GRANT ALL ON FUNCTION step003_000_load_classification_relationship(cls_version_sid integer) TO postgres;
GRANT ALL ON FUNCTION step003_000_load_classification_relationship(cls_version_sid integer) TO PUBLIC;
GRANT ALL ON FUNCTION step003_000_load_classification_relationship(cls_version_sid integer) TO panther_users;


--
-- TOC entry 5046 (class 0 OID 0)
-- Dependencies: 736
-- Name: step003_001_load_classification_relationship_with_goslim(integer); Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON FUNCTION step003_001_load_classification_relationship_with_goslim(cls_version_sid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION step003_001_load_classification_relationship_with_goslim(cls_version_sid integer) FROM postgres;
GRANT ALL ON FUNCTION step003_001_load_classification_relationship_with_goslim(cls_version_sid integer) TO postgres;
GRANT ALL ON FUNCTION step003_001_load_classification_relationship_with_goslim(cls_version_sid integer) TO PUBLIC;
GRANT ALL ON FUNCTION step003_001_load_classification_relationship_with_goslim(cls_version_sid integer) TO panther_users;


--
-- TOC entry 5047 (class 0 OID 0)
-- Dependencies: 738
-- Name: step003_002_load_classification_relationship_with_protein_class(integer); Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON FUNCTION step003_002_load_classification_relationship_with_protein_class(cls_version_sid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION step003_002_load_classification_relationship_with_protein_class(cls_version_sid integer) FROM postgres;
GRANT ALL ON FUNCTION step003_002_load_classification_relationship_with_protein_class(cls_version_sid integer) TO postgres;
GRANT ALL ON FUNCTION step003_002_load_classification_relationship_with_protein_class(cls_version_sid integer) TO PUBLIC;
GRANT ALL ON FUNCTION step003_002_load_classification_relationship_with_protein_class(cls_version_sid integer) TO panther_users;


--
-- TOC entry 5048 (class 0 OID 0)
-- Dependencies: 728
-- Name: step004_000_load_organism(integer); Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON FUNCTION step004_000_load_organism(cls_version_sid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION step004_000_load_organism(cls_version_sid integer) FROM postgres;
GRANT ALL ON FUNCTION step004_000_load_organism(cls_version_sid integer) TO postgres;
GRANT ALL ON FUNCTION step004_000_load_organism(cls_version_sid integer) TO PUBLIC;
GRANT ALL ON FUNCTION step004_000_load_organism(cls_version_sid integer) TO panther_users;


--
-- TOC entry 5049 (class 0 OID 0)
-- Dependencies: 754
-- Name: step005_000_load_gene(integer); Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON FUNCTION step005_000_load_gene(cls_version_sid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION step005_000_load_gene(cls_version_sid integer) FROM postgres;
GRANT ALL ON FUNCTION step005_000_load_gene(cls_version_sid integer) TO postgres;
GRANT ALL ON FUNCTION step005_000_load_gene(cls_version_sid integer) TO PUBLIC;
GRANT ALL ON FUNCTION step005_000_load_gene(cls_version_sid integer) TO panther_users;


--
-- TOC entry 5050 (class 0 OID 0)
-- Dependencies: 798
-- Name: step006_000_load_transcript(integer); Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON FUNCTION step006_000_load_transcript(cls_version_sid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION step006_000_load_transcript(cls_version_sid integer) FROM postgres;
GRANT ALL ON FUNCTION step006_000_load_transcript(cls_version_sid integer) TO postgres;
GRANT ALL ON FUNCTION step006_000_load_transcript(cls_version_sid integer) TO PUBLIC;
GRANT ALL ON FUNCTION step006_000_load_transcript(cls_version_sid integer) TO panther_users;


--
-- TOC entry 5051 (class 0 OID 0)
-- Dependencies: 744
-- Name: step007_000_load_protein(integer); Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON FUNCTION step007_000_load_protein(cls_version_sid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION step007_000_load_protein(cls_version_sid integer) FROM postgres;
GRANT ALL ON FUNCTION step007_000_load_protein(cls_version_sid integer) TO postgres;
GRANT ALL ON FUNCTION step007_000_load_protein(cls_version_sid integer) TO PUBLIC;
GRANT ALL ON FUNCTION step007_000_load_protein(cls_version_sid integer) TO panther_users;


--
-- TOC entry 5052 (class 0 OID 0)
-- Dependencies: 745
-- Name: step007_001_update_protein(integer); Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON FUNCTION step007_001_update_protein(cls_version_sid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION step007_001_update_protein(cls_version_sid integer) FROM postgres;
GRANT ALL ON FUNCTION step007_001_update_protein(cls_version_sid integer) TO postgres;
GRANT ALL ON FUNCTION step007_001_update_protein(cls_version_sid integer) TO PUBLIC;
GRANT ALL ON FUNCTION step007_001_update_protein(cls_version_sid integer) TO panther_users;


--
-- TOC entry 5053 (class 0 OID 0)
-- Dependencies: 767
-- Name: step008_000_update_sequence_source(integer); Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON FUNCTION step008_000_update_sequence_source(cls_version_sid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION step008_000_update_sequence_source(cls_version_sid integer) FROM postgres;
GRANT ALL ON FUNCTION step008_000_update_sequence_source(cls_version_sid integer) TO postgres;
GRANT ALL ON FUNCTION step008_000_update_sequence_source(cls_version_sid integer) TO PUBLIC;
GRANT ALL ON FUNCTION step008_000_update_sequence_source(cls_version_sid integer) TO panther_users;


--
-- TOC entry 5054 (class 0 OID 0)
-- Dependencies: 746
-- Name: step009_001_update_primary_object_protein(integer); Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON FUNCTION step009_001_update_primary_object_protein(cls_version_sid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION step009_001_update_primary_object_protein(cls_version_sid integer) FROM postgres;
GRANT ALL ON FUNCTION step009_001_update_primary_object_protein(cls_version_sid integer) TO postgres;
GRANT ALL ON FUNCTION step009_001_update_primary_object_protein(cls_version_sid integer) TO PUBLIC;
GRANT ALL ON FUNCTION step009_001_update_primary_object_protein(cls_version_sid integer) TO panther_users;


--
-- TOC entry 5055 (class 0 OID 0)
-- Dependencies: 768
-- Name: step009_002_update_primary_object_transcript(integer); Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON FUNCTION step009_002_update_primary_object_transcript(cls_version_sid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION step009_002_update_primary_object_transcript(cls_version_sid integer) FROM postgres;
GRANT ALL ON FUNCTION step009_002_update_primary_object_transcript(cls_version_sid integer) TO postgres;
GRANT ALL ON FUNCTION step009_002_update_primary_object_transcript(cls_version_sid integer) TO PUBLIC;
GRANT ALL ON FUNCTION step009_002_update_primary_object_transcript(cls_version_sid integer) TO panther_users;


--
-- TOC entry 5056 (class 0 OID 0)
-- Dependencies: 755
-- Name: step009_003_update_primary_object_gene(integer); Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON FUNCTION step009_003_update_primary_object_gene(cls_version_sid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION step009_003_update_primary_object_gene(cls_version_sid integer) FROM postgres;
GRANT ALL ON FUNCTION step009_003_update_primary_object_gene(cls_version_sid integer) TO postgres;
GRANT ALL ON FUNCTION step009_003_update_primary_object_gene(cls_version_sid integer) TO PUBLIC;
GRANT ALL ON FUNCTION step009_003_update_primary_object_gene(cls_version_sid integer) TO panther_users;


--
-- TOC entry 5057 (class 0 OID 0)
-- Dependencies: 756
-- Name: step010_000_update_tree_detail(integer); Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON FUNCTION step010_000_update_tree_detail(cls_version_sid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION step010_000_update_tree_detail(cls_version_sid integer) FROM postgres;
GRANT ALL ON FUNCTION step010_000_update_tree_detail(cls_version_sid integer) TO postgres;
GRANT ALL ON FUNCTION step010_000_update_tree_detail(cls_version_sid integer) TO PUBLIC;
GRANT ALL ON FUNCTION step010_000_update_tree_detail(cls_version_sid integer) TO panther_users;


--
-- TOC entry 5058 (class 0 OID 0)
-- Dependencies: 757
-- Name: step011_000_update_node(integer); Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON FUNCTION step011_000_update_node(cls_version_sid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION step011_000_update_node(cls_version_sid integer) FROM postgres;
GRANT ALL ON FUNCTION step011_000_update_node(cls_version_sid integer) TO postgres;
GRANT ALL ON FUNCTION step011_000_update_node(cls_version_sid integer) TO PUBLIC;
GRANT ALL ON FUNCTION step011_000_update_node(cls_version_sid integer) TO panther_users;


--
-- TOC entry 5059 (class 0 OID 0)
-- Dependencies: 758
-- Name: step012_000_update_gene_node(integer); Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON FUNCTION step012_000_update_gene_node(cls_version_sid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION step012_000_update_gene_node(cls_version_sid integer) FROM postgres;
GRANT ALL ON FUNCTION step012_000_update_gene_node(cls_version_sid integer) TO postgres;
GRANT ALL ON FUNCTION step012_000_update_gene_node(cls_version_sid integer) TO PUBLIC;
GRANT ALL ON FUNCTION step012_000_update_gene_node(cls_version_sid integer) TO panther_users;


--
-- TOC entry 5060 (class 0 OID 0)
-- Dependencies: 759
-- Name: step013_000_update_protein_node(integer); Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON FUNCTION step013_000_update_protein_node(cls_version_sid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION step013_000_update_protein_node(cls_version_sid integer) FROM postgres;
GRANT ALL ON FUNCTION step013_000_update_protein_node(cls_version_sid integer) TO postgres;
GRANT ALL ON FUNCTION step013_000_update_protein_node(cls_version_sid integer) TO PUBLIC;
GRANT ALL ON FUNCTION step013_000_update_protein_node(cls_version_sid integer) TO panther_users;


--
-- TOC entry 5061 (class 0 OID 0)
-- Dependencies: 760
-- Name: step014_000_update_node_relationship(integer); Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON FUNCTION step014_000_update_node_relationship(cls_version_sid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION step014_000_update_node_relationship(cls_version_sid integer) FROM postgres;
GRANT ALL ON FUNCTION step014_000_update_node_relationship(cls_version_sid integer) TO postgres;
GRANT ALL ON FUNCTION step014_000_update_node_relationship(cls_version_sid integer) TO PUBLIC;
GRANT ALL ON FUNCTION step014_000_update_node_relationship(cls_version_sid integer) TO panther_users;


--
-- TOC entry 5062 (class 0 OID 0)
-- Dependencies: 741
-- Name: step015_000_update_identifier(integer); Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON FUNCTION step015_000_update_identifier(cls_version_sid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION step015_000_update_identifier(cls_version_sid integer) FROM postgres;
GRANT ALL ON FUNCTION step015_000_update_identifier(cls_version_sid integer) TO postgres;
GRANT ALL ON FUNCTION step015_000_update_identifier(cls_version_sid integer) TO PUBLIC;
GRANT ALL ON FUNCTION step015_000_update_identifier(cls_version_sid integer) TO panther_users;


--
-- TOC entry 5063 (class 0 OID 0)
-- Dependencies: 739
-- Name: step016_000_update_annotation(integer); Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON FUNCTION step016_000_update_annotation(cls_version_sid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION step016_000_update_annotation(cls_version_sid integer) FROM postgres;
GRANT ALL ON FUNCTION step016_000_update_annotation(cls_version_sid integer) TO postgres;
GRANT ALL ON FUNCTION step016_000_update_annotation(cls_version_sid integer) TO PUBLIC;
GRANT ALL ON FUNCTION step016_000_update_annotation(cls_version_sid integer) TO panther_users;


--
-- TOC entry 5064 (class 0 OID 0)
-- Dependencies: 748
-- Name: step017_000_update_annotation_qualifier(integer); Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON FUNCTION step017_000_update_annotation_qualifier(cls_version_sid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION step017_000_update_annotation_qualifier(cls_version_sid integer) FROM postgres;
GRANT ALL ON FUNCTION step017_000_update_annotation_qualifier(cls_version_sid integer) TO postgres;
GRANT ALL ON FUNCTION step017_000_update_annotation_qualifier(cls_version_sid integer) TO PUBLIC;
GRANT ALL ON FUNCTION step017_000_update_annotation_qualifier(cls_version_sid integer) TO panther_users;


--
-- TOC entry 5065 (class 0 OID 0)
-- Dependencies: 740
-- Name: step018_000_update_confidence_code(); Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON FUNCTION step018_000_update_confidence_code() FROM PUBLIC;
REVOKE ALL ON FUNCTION step018_000_update_confidence_code() FROM postgres;
GRANT ALL ON FUNCTION step018_000_update_confidence_code() TO postgres;
GRANT ALL ON FUNCTION step018_000_update_confidence_code() TO PUBLIC;
GRANT ALL ON FUNCTION step018_000_update_confidence_code() TO panther_users;


--
-- TOC entry 5066 (class 0 OID 0)
-- Dependencies: 761
-- Name: step019_000_update_pathway_curation(integer); Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON FUNCTION step019_000_update_pathway_curation(cls_version_sid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION step019_000_update_pathway_curation(cls_version_sid integer) FROM postgres;
GRANT ALL ON FUNCTION step019_000_update_pathway_curation(cls_version_sid integer) TO postgres;
GRANT ALL ON FUNCTION step019_000_update_pathway_curation(cls_version_sid integer) TO PUBLIC;
GRANT ALL ON FUNCTION step019_000_update_pathway_curation(cls_version_sid integer) TO panther_users;


--
-- TOC entry 5067 (class 0 OID 0)
-- Dependencies: 787
-- Name: step020_000_update_evidence(integer, integer); Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON FUNCTION step020_000_update_evidence(cls_version_sid integer, pthwy_version_sid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION step020_000_update_evidence(cls_version_sid integer, pthwy_version_sid integer) FROM postgres;
GRANT ALL ON FUNCTION step020_000_update_evidence(cls_version_sid integer, pthwy_version_sid integer) TO postgres;
GRANT ALL ON FUNCTION step020_000_update_evidence(cls_version_sid integer, pthwy_version_sid integer) TO PUBLIC;
GRANT ALL ON FUNCTION step020_000_update_evidence(cls_version_sid integer, pthwy_version_sid integer) TO panther_users;


--
-- TOC entry 5068 (class 0 OID 0)
-- Dependencies: 799
-- Name: step020_000_update_evidence_upl12(integer, integer); Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON FUNCTION step020_000_update_evidence_upl12(cls_version_sid integer, pthwy_version_sid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION step020_000_update_evidence_upl12(cls_version_sid integer, pthwy_version_sid integer) FROM postgres;
GRANT ALL ON FUNCTION step020_000_update_evidence_upl12(cls_version_sid integer, pthwy_version_sid integer) TO postgres;
GRANT ALL ON FUNCTION step020_000_update_evidence_upl12(cls_version_sid integer, pthwy_version_sid integer) TO PUBLIC;
GRANT ALL ON FUNCTION step020_000_update_evidence_upl12(cls_version_sid integer, pthwy_version_sid integer) TO panther_users;


--
-- TOC entry 5069 (class 0 OID 0)
-- Dependencies: 762
-- Name: step020_001_update_evidence(integer); Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON FUNCTION step020_001_update_evidence(pthwy_version_sid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION step020_001_update_evidence(pthwy_version_sid integer) FROM postgres;
GRANT ALL ON FUNCTION step020_001_update_evidence(pthwy_version_sid integer) TO postgres;
GRANT ALL ON FUNCTION step020_001_update_evidence(pthwy_version_sid integer) TO PUBLIC;
GRANT ALL ON FUNCTION step020_001_update_evidence(pthwy_version_sid integer) TO panther_users;


--
-- TOC entry 5070 (class 0 OID 0)
-- Dependencies: 763
-- Name: step021_000_update_map_location(integer); Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON FUNCTION step021_000_update_map_location(cls_version_sid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION step021_000_update_map_location(cls_version_sid integer) FROM postgres;
GRANT ALL ON FUNCTION step021_000_update_map_location(cls_version_sid integer) TO postgres;
GRANT ALL ON FUNCTION step021_000_update_map_location(cls_version_sid integer) TO PUBLIC;
GRANT ALL ON FUNCTION step021_000_update_map_location(cls_version_sid integer) TO panther_users;


--
-- TOC entry 5071 (class 0 OID 0)
-- Dependencies: 764
-- Name: step022_000_update_classification_relationship_with_sf_cat(integer, integer, integer); Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON FUNCTION step022_000_update_classification_relationship_with_sf_cat(cls_version_sid integer, cat_version_sid integer, ont_version_sid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION step022_000_update_classification_relationship_with_sf_cat(cls_version_sid integer, cat_version_sid integer, ont_version_sid integer) FROM postgres;
GRANT ALL ON FUNCTION step022_000_update_classification_relationship_with_sf_cat(cls_version_sid integer, cat_version_sid integer, ont_version_sid integer) TO postgres;
GRANT ALL ON FUNCTION step022_000_update_classification_relationship_with_sf_cat(cls_version_sid integer, cat_version_sid integer, ont_version_sid integer) TO PUBLIC;
GRANT ALL ON FUNCTION step022_000_update_classification_relationship_with_sf_cat(cls_version_sid integer, cat_version_sid integer, ont_version_sid integer) TO panther_users;


--
-- TOC entry 5072 (class 0 OID 0)
-- Dependencies: 765
-- Name: step023_000_update_protein_classification(integer); Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON FUNCTION step023_000_update_protein_classification(cls_version_sid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION step023_000_update_protein_classification(cls_version_sid integer) FROM postgres;
GRANT ALL ON FUNCTION step023_000_update_protein_classification(cls_version_sid integer) TO postgres;
GRANT ALL ON FUNCTION step023_000_update_protein_classification(cls_version_sid integer) TO PUBLIC;
GRANT ALL ON FUNCTION step023_000_update_protein_classification(cls_version_sid integer) TO panther_users;


--
-- TOC entry 5073 (class 0 OID 0)
-- Dependencies: 337
-- Name: abstract; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE abstract FROM PUBLIC;
REVOKE ALL ON TABLE abstract FROM panther_upl;
GRANT ALL ON TABLE abstract TO panther_upl;
GRANT ALL ON TABLE abstract TO panther_users;
GRANT ALL ON TABLE abstract TO panther_paint;


--
-- TOC entry 5074 (class 0 OID 0)
-- Dependencies: 338
-- Name: abstract_type; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE abstract_type FROM PUBLIC;
REVOKE ALL ON TABLE abstract_type FROM panther_upl;
GRANT ALL ON TABLE abstract_type TO panther_upl;
GRANT ALL ON TABLE abstract_type TO panther_users;
GRANT ALL ON TABLE abstract_type TO panther_paint;


--
-- TOC entry 5075 (class 0 OID 0)
-- Dependencies: 339
-- Name: add_cat_subfam; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE add_cat_subfam FROM PUBLIC;
REVOKE ALL ON TABLE add_cat_subfam FROM panther_upl;
GRANT ALL ON TABLE add_cat_subfam TO panther_upl;
GRANT ALL ON TABLE add_cat_subfam TO panther_users;
GRANT ALL ON TABLE add_cat_subfam TO panther_paint;


--
-- TOC entry 5076 (class 0 OID 0)
-- Dependencies: 340
-- Name: annotation; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE annotation FROM PUBLIC;
REVOKE ALL ON TABLE annotation FROM panther_upl;
GRANT ALL ON TABLE annotation TO panther_upl;
GRANT ALL ON TABLE annotation TO panther_users;
GRANT ALL ON TABLE annotation TO panther_paint;


--
-- TOC entry 5077 (class 0 OID 0)
-- Dependencies: 341
-- Name: annotation_qualifier; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE annotation_qualifier FROM PUBLIC;
REVOKE ALL ON TABLE annotation_qualifier FROM panther_upl;
GRANT ALL ON TABLE annotation_qualifier TO panther_upl;
GRANT ALL ON TABLE annotation_qualifier TO panther_users;
GRANT ALL ON TABLE annotation_qualifier TO panther_paint;


--
-- TOC entry 5078 (class 0 OID 0)
-- Dependencies: 342
-- Name: annotation_type; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE annotation_type FROM PUBLIC;
REVOKE ALL ON TABLE annotation_type FROM panther_upl;
GRANT ALL ON TABLE annotation_type TO panther_upl;
GRANT ALL ON TABLE annotation_type TO panther_users;
GRANT ALL ON TABLE annotation_type TO panther_paint;


--
-- TOC entry 5079 (class 0 OID 0)
-- Dependencies: 343
-- Name: bio_sequence; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE bio_sequence FROM PUBLIC;
REVOKE ALL ON TABLE bio_sequence FROM panther_upl;
GRANT ALL ON TABLE bio_sequence TO panther_upl;
GRANT ALL ON TABLE bio_sequence TO panther_users;
GRANT ALL ON TABLE bio_sequence TO panther_paint;


--
-- TOC entry 5080 (class 0 OID 0)
-- Dependencies: 344
-- Name: cat_relation; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE cat_relation FROM PUBLIC;
REVOKE ALL ON TABLE cat_relation FROM panther_upl;
GRANT ALL ON TABLE cat_relation TO panther_upl;
GRANT ALL ON TABLE cat_relation TO panther_users;
GRANT ALL ON TABLE cat_relation TO panther_paint;


--
-- TOC entry 5081 (class 0 OID 0)
-- Dependencies: 345
-- Name: classification; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE classification FROM PUBLIC;
REVOKE ALL ON TABLE classification FROM panther_upl;
GRANT ALL ON TABLE classification TO panther_upl;
GRANT ALL ON TABLE classification TO panther_users;
GRANT ALL ON TABLE classification TO panther_paint;


--
-- TOC entry 5082 (class 0 OID 0)
-- Dependencies: 346
-- Name: classification_mapping; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE classification_mapping FROM PUBLIC;
REVOKE ALL ON TABLE classification_mapping FROM panther_upl;
GRANT ALL ON TABLE classification_mapping TO panther_upl;
GRANT ALL ON TABLE classification_mapping TO panther_users;
GRANT ALL ON TABLE classification_mapping TO panther_paint;


--
-- TOC entry 5083 (class 0 OID 0)
-- Dependencies: 347
-- Name: classification_relationship; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE classification_relationship FROM PUBLIC;
REVOKE ALL ON TABLE classification_relationship FROM panther_upl;
GRANT ALL ON TABLE classification_relationship TO panther_upl;
GRANT ALL ON TABLE classification_relationship TO panther_users;
GRANT ALL ON TABLE classification_relationship TO panther_paint;


--
-- TOC entry 5084 (class 0 OID 0)
-- Dependencies: 348
-- Name: classification_term_type; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE classification_term_type FROM PUBLIC;
REVOKE ALL ON TABLE classification_term_type FROM panther_upl;
GRANT ALL ON TABLE classification_term_type TO panther_upl;
GRANT ALL ON TABLE classification_term_type TO panther_users;
GRANT ALL ON TABLE classification_term_type TO panther_paint;


--
-- TOC entry 5085 (class 0 OID 0)
-- Dependencies: 349
-- Name: classification_type; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE classification_type FROM PUBLIC;
REVOKE ALL ON TABLE classification_type FROM panther_upl;
GRANT ALL ON TABLE classification_type TO panther_upl;
GRANT ALL ON TABLE classification_type TO panther_users;
GRANT ALL ON TABLE classification_type TO panther_paint;


--
-- TOC entry 5086 (class 0 OID 0)
-- Dependencies: 350
-- Name: classification_version; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE classification_version FROM PUBLIC;
REVOKE ALL ON TABLE classification_version FROM panther_upl;
GRANT ALL ON TABLE classification_version TO panther_upl;
GRANT ALL ON TABLE classification_version TO panther_users;
GRANT ALL ON TABLE classification_version TO panther_paint;


--
-- TOC entry 5087 (class 0 OID 0)
-- Dependencies: 351
-- Name: comments; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE comments FROM PUBLIC;
REVOKE ALL ON TABLE comments FROM panther_upl;
GRANT ALL ON TABLE comments TO panther_upl;
GRANT ALL ON TABLE comments TO panther_users;
GRANT ALL ON TABLE comments TO panther_paint;


--
-- TOC entry 5088 (class 0 OID 0)
-- Dependencies: 352
-- Name: common_annotation_block; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE common_annotation_block FROM PUBLIC;
REVOKE ALL ON TABLE common_annotation_block FROM panther_upl;
GRANT ALL ON TABLE common_annotation_block TO panther_upl;
GRANT ALL ON TABLE common_annotation_block TO panther_users;
GRANT ALL ON TABLE common_annotation_block TO panther_paint;


--
-- TOC entry 5089 (class 0 OID 0)
-- Dependencies: 353
-- Name: confidence_code; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE confidence_code FROM PUBLIC;
REVOKE ALL ON TABLE confidence_code FROM panther_upl;
GRANT ALL ON TABLE confidence_code TO panther_upl;
GRANT ALL ON TABLE confidence_code TO panther_users;
GRANT ALL ON TABLE confidence_code TO panther_paint;


--
-- TOC entry 5090 (class 0 OID 0)
-- Dependencies: 354
-- Name: curation_status; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE curation_status FROM PUBLIC;
REVOKE ALL ON TABLE curation_status FROM panther_upl;
GRANT ALL ON TABLE curation_status TO panther_upl;
GRANT ALL ON TABLE curation_status TO panther_users;
GRANT ALL ON TABLE curation_status TO panther_paint;


--
-- TOC entry 5091 (class 0 OID 0)
-- Dependencies: 677
-- Name: curation_status_new_v12; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE curation_status_new_v12 FROM PUBLIC;
REVOKE ALL ON TABLE curation_status_new_v12 FROM panther_upl;
GRANT ALL ON TABLE curation_status_new_v12 TO panther_upl;
GRANT ALL ON TABLE curation_status_new_v12 TO panther_users;
GRANT ALL ON TABLE curation_status_new_v12 TO panther_paint;


--
-- TOC entry 5092 (class 0 OID 0)
-- Dependencies: 355
-- Name: curation_status_type; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE curation_status_type FROM PUBLIC;
REVOKE ALL ON TABLE curation_status_type FROM panther_upl;
GRANT ALL ON TABLE curation_status_type TO panther_upl;
GRANT ALL ON TABLE curation_status_type TO panther_users;
GRANT ALL ON TABLE curation_status_type TO panther_paint;


--
-- TOC entry 5093 (class 0 OID 0)
-- Dependencies: 356
-- Name: event_type; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE event_type FROM PUBLIC;
REVOKE ALL ON TABLE event_type FROM panther_upl;
GRANT ALL ON TABLE event_type TO panther_upl;
GRANT ALL ON TABLE event_type TO panther_users;
GRANT ALL ON TABLE event_type TO panther_paint;


--
-- TOC entry 5095 (class 0 OID 0)
-- Dependencies: 460
-- Name: evidence; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE evidence FROM PUBLIC;
REVOKE ALL ON TABLE evidence FROM panther_upl;
GRANT ALL ON TABLE evidence TO panther_upl;
GRANT ALL ON TABLE evidence TO panther_users;
GRANT ALL ON TABLE evidence TO panther_paint;


--
-- TOC entry 5097 (class 0 OID 0)
-- Dependencies: 357
-- Name: evidence_old; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE evidence_old FROM PUBLIC;
REVOKE ALL ON TABLE evidence_old FROM panther_upl;
GRANT ALL ON TABLE evidence_old TO panther_upl;
GRANT ALL ON TABLE evidence_old TO panther_users;
GRANT ALL ON TABLE evidence_old TO panther_paint;


--
-- TOC entry 5098 (class 0 OID 0)
-- Dependencies: 358
-- Name: evidence_type; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE evidence_type FROM PUBLIC;
REVOKE ALL ON TABLE evidence_type FROM panther_upl;
GRANT ALL ON TABLE evidence_type TO panther_upl;
GRANT ALL ON TABLE evidence_type TO panther_users;
GRANT ALL ON TABLE evidence_type TO panther_paint;


--
-- TOC entry 5099 (class 0 OID 0)
-- Dependencies: 359
-- Name: family_to_sequence_save; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE family_to_sequence_save FROM PUBLIC;
REVOKE ALL ON TABLE family_to_sequence_save FROM panther_upl;
GRANT ALL ON TABLE family_to_sequence_save TO panther_upl;
GRANT ALL ON TABLE family_to_sequence_save TO panther_users;
GRANT ALL ON TABLE family_to_sequence_save TO panther_paint;


--
-- TOC entry 5100 (class 0 OID 0)
-- Dependencies: 360
-- Name: feature; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE feature FROM PUBLIC;
REVOKE ALL ON TABLE feature FROM panther_upl;
GRANT ALL ON TABLE feature TO panther_upl;
GRANT ALL ON TABLE feature TO panther_users;
GRANT ALL ON TABLE feature TO panther_paint;


--
-- TOC entry 5101 (class 0 OID 0)
-- Dependencies: 361
-- Name: feature_type; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE feature_type FROM PUBLIC;
REVOKE ALL ON TABLE feature_type FROM panther_upl;
GRANT ALL ON TABLE feature_type TO panther_upl;
GRANT ALL ON TABLE feature_type TO panther_users;
GRANT ALL ON TABLE feature_type TO panther_paint;


--
-- TOC entry 5102 (class 0 OID 0)
-- Dependencies: 362
-- Name: fill_parent_category; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE fill_parent_category FROM PUBLIC;
REVOKE ALL ON TABLE fill_parent_category FROM panther_upl;
GRANT ALL ON TABLE fill_parent_category TO panther_upl;
GRANT ALL ON TABLE fill_parent_category TO panther_users;
GRANT ALL ON TABLE fill_parent_category TO panther_paint;


--
-- TOC entry 5103 (class 0 OID 0)
-- Dependencies: 363
-- Name: gene; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE gene FROM PUBLIC;
REVOKE ALL ON TABLE gene FROM panther_upl;
GRANT ALL ON TABLE gene TO panther_upl;
GRANT ALL ON TABLE gene TO panther_users;
GRANT ALL ON TABLE gene TO panther_paint;


--
-- TOC entry 5104 (class 0 OID 0)
-- Dependencies: 364
-- Name: gene_node; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE gene_node FROM PUBLIC;
REVOKE ALL ON TABLE gene_node FROM panther_upl;
GRANT ALL ON TABLE gene_node TO panther_upl;
GRANT ALL ON TABLE gene_node TO panther_users;
GRANT ALL ON TABLE gene_node TO panther_paint;


--
-- TOC entry 5105 (class 0 OID 0)
-- Dependencies: 478
-- Name: gene_node_production; Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON TABLE gene_node_production FROM PUBLIC;
REVOKE ALL ON TABLE gene_node_production FROM postgres;
GRANT ALL ON TABLE gene_node_production TO postgres;
GRANT ALL ON TABLE gene_node_production TO panther_paint;


--
-- TOC entry 5106 (class 0 OID 0)
-- Dependencies: 479
-- Name: gene_production; Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON TABLE gene_production FROM PUBLIC;
REVOKE ALL ON TABLE gene_production FROM postgres;
GRANT ALL ON TABLE gene_production TO postgres;
GRANT ALL ON TABLE gene_production TO panther_paint;


--
-- TOC entry 5107 (class 0 OID 0)
-- Dependencies: 365
-- Name: gene_protein; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE gene_protein FROM PUBLIC;
REVOKE ALL ON TABLE gene_protein FROM panther_upl;
GRANT ALL ON TABLE gene_protein TO panther_upl;
GRANT ALL ON TABLE gene_protein TO panther_users;
GRANT ALL ON TABLE gene_protein TO panther_paint;


--
-- TOC entry 5108 (class 0 OID 0)
-- Dependencies: 489
-- Name: genelist_agg; Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON TABLE genelist_agg FROM PUBLIC;
REVOKE ALL ON TABLE genelist_agg FROM postgres;
GRANT ALL ON TABLE genelist_agg TO postgres;
GRANT ALL ON TABLE genelist_agg TO panther_paint;


--
-- TOC entry 5109 (class 0 OID 0)
-- Dependencies: 679
-- Name: go_annotation; Type: ACL; Schema: panther_upl; Owner: panther_isp
--

REVOKE ALL ON TABLE go_annotation FROM PUBLIC;
REVOKE ALL ON TABLE go_annotation FROM panther_isp;
GRANT ALL ON TABLE go_annotation TO panther_isp;
GRANT ALL ON TABLE go_annotation TO panther_upl;
GRANT ALL ON TABLE go_annotation TO panther_paint;


--
-- TOC entry 5110 (class 0 OID 0)
-- Dependencies: 681
-- Name: go_annotation_qualifier; Type: ACL; Schema: panther_upl; Owner: panther_isp
--

REVOKE ALL ON TABLE go_annotation_qualifier FROM PUBLIC;
REVOKE ALL ON TABLE go_annotation_qualifier FROM panther_isp;
GRANT ALL ON TABLE go_annotation_qualifier TO panther_isp;
GRANT ALL ON TABLE go_annotation_qualifier TO panther_upl;
GRANT ALL ON TABLE go_annotation_qualifier TO panther_paint;


--
-- TOC entry 5111 (class 0 OID 0)
-- Dependencies: 491
-- Name: go_classification; Type: ACL; Schema: panther_upl; Owner: panther_isp
--

REVOKE ALL ON TABLE go_classification FROM PUBLIC;
REVOKE ALL ON TABLE go_classification FROM panther_isp;
GRANT ALL ON TABLE go_classification TO panther_isp;
GRANT ALL ON TABLE go_classification TO panther_upl;
GRANT ALL ON TABLE go_classification TO panther_paint;


--
-- TOC entry 5112 (class 0 OID 0)
-- Dependencies: 680
-- Name: go_evidence; Type: ACL; Schema: panther_upl; Owner: panther_isp
--

REVOKE ALL ON TABLE go_evidence FROM PUBLIC;
REVOKE ALL ON TABLE go_evidence FROM panther_isp;
GRANT ALL ON TABLE go_evidence TO panther_isp;
GRANT ALL ON TABLE go_evidence TO panther_upl;
GRANT ALL ON TABLE go_evidence TO panther_paint;


--
-- TOC entry 5113 (class 0 OID 0)
-- Dependencies: 376
-- Name: node; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE node FROM PUBLIC;
REVOKE ALL ON TABLE node FROM panther_upl;
GRANT ALL ON TABLE node TO panther_upl;
GRANT ALL ON TABLE node TO panther_users;
GRANT ALL ON TABLE node TO panther_paint;


--
-- TOC entry 5114 (class 0 OID 0)
-- Dependencies: 400
-- Name: qualifier; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE qualifier FROM PUBLIC;
REVOKE ALL ON TABLE qualifier FROM panther_upl;
GRANT ALL ON TABLE qualifier TO panther_upl;
GRANT ALL ON TABLE qualifier TO panther_users;
GRANT ALL ON TABLE qualifier TO panther_paint;


--
-- TOC entry 5115 (class 0 OID 0)
-- Dependencies: 690
-- Name: go_aggregate; Type: ACL; Schema: panther_upl; Owner: panther_isp
--

REVOKE ALL ON TABLE go_aggregate FROM PUBLIC;
REVOKE ALL ON TABLE go_aggregate FROM panther_isp;
GRANT ALL ON TABLE go_aggregate TO panther_isp;
GRANT ALL ON TABLE go_aggregate TO panther_users;
GRANT ALL ON TABLE go_aggregate TO panther_paint;
GRANT ALL ON TABLE go_aggregate TO panther_upl;


--
-- TOC entry 5116 (class 0 OID 0)
-- Dependencies: 683
-- Name: go_annotation_new_v12; Type: ACL; Schema: panther_upl; Owner: panther_isp
--

REVOKE ALL ON TABLE go_annotation_new_v12 FROM PUBLIC;
REVOKE ALL ON TABLE go_annotation_new_v12 FROM panther_isp;
GRANT ALL ON TABLE go_annotation_new_v12 TO panther_isp;
GRANT ALL ON TABLE go_annotation_new_v12 TO panther_upl;
GRANT ALL ON TABLE go_annotation_new_v12 TO panther_paint;


--
-- TOC entry 5117 (class 0 OID 0)
-- Dependencies: 484
-- Name: go_annotation_old; Type: ACL; Schema: panther_upl; Owner: panther_isp
--

REVOKE ALL ON TABLE go_annotation_old FROM PUBLIC;
REVOKE ALL ON TABLE go_annotation_old FROM panther_isp;
GRANT ALL ON TABLE go_annotation_old TO panther_isp;
GRANT ALL ON TABLE go_annotation_old TO panther_upl;
GRANT ALL ON TABLE go_annotation_old TO panther_paint;


--
-- TOC entry 5118 (class 0 OID 0)
-- Dependencies: 687
-- Name: go_annotation_qualifier_new_v12; Type: ACL; Schema: panther_upl; Owner: panther_isp
--

REVOKE ALL ON TABLE go_annotation_qualifier_new_v12 FROM PUBLIC;
REVOKE ALL ON TABLE go_annotation_qualifier_new_v12 FROM panther_isp;
GRANT ALL ON TABLE go_annotation_qualifier_new_v12 TO panther_isp;
GRANT ALL ON TABLE go_annotation_qualifier_new_v12 TO panther_upl;
GRANT ALL ON TABLE go_annotation_qualifier_new_v12 TO panther_paint;


--
-- TOC entry 5119 (class 0 OID 0)
-- Dependencies: 485
-- Name: go_annotation_qualifier_old; Type: ACL; Schema: panther_upl; Owner: panther_isp
--

REVOKE ALL ON TABLE go_annotation_qualifier_old FROM PUBLIC;
REVOKE ALL ON TABLE go_annotation_qualifier_old FROM panther_isp;
GRANT ALL ON TABLE go_annotation_qualifier_old TO panther_isp;
GRANT ALL ON TABLE go_annotation_qualifier_old TO panther_upl;
GRANT ALL ON TABLE go_annotation_qualifier_old TO panther_paint;


--
-- TOC entry 5120 (class 0 OID 0)
-- Dependencies: 486
-- Name: go_classification_old; Type: ACL; Schema: panther_upl; Owner: panther_isp
--

REVOKE ALL ON TABLE go_classification_old FROM PUBLIC;
REVOKE ALL ON TABLE go_classification_old FROM panther_isp;
GRANT ALL ON TABLE go_classification_old TO panther_isp;
GRANT ALL ON TABLE go_classification_old TO panther_upl;
GRANT ALL ON TABLE go_classification_old TO panther_paint;


--
-- TOC entry 5121 (class 0 OID 0)
-- Dependencies: 492
-- Name: go_classification_relationship; Type: ACL; Schema: panther_upl; Owner: panther_isp
--

REVOKE ALL ON TABLE go_classification_relationship FROM PUBLIC;
REVOKE ALL ON TABLE go_classification_relationship FROM panther_isp;
GRANT ALL ON TABLE go_classification_relationship TO panther_isp;
GRANT ALL ON TABLE go_classification_relationship TO panther_upl;
GRANT ALL ON TABLE go_classification_relationship TO panther_paint;


--
-- TOC entry 5122 (class 0 OID 0)
-- Dependencies: 487
-- Name: go_classification_relationship_old; Type: ACL; Schema: panther_upl; Owner: panther_isp
--

REVOKE ALL ON TABLE go_classification_relationship_old FROM PUBLIC;
REVOKE ALL ON TABLE go_classification_relationship_old FROM panther_isp;
GRANT ALL ON TABLE go_classification_relationship_old TO panther_isp;
GRANT ALL ON TABLE go_classification_relationship_old TO panther_upl;
GRANT ALL ON TABLE go_classification_relationship_old TO panther_paint;


--
-- TOC entry 5123 (class 0 OID 0)
-- Dependencies: 686
-- Name: go_evidence_new_v12; Type: ACL; Schema: panther_upl; Owner: panther_isp
--

REVOKE ALL ON TABLE go_evidence_new_v12 FROM PUBLIC;
REVOKE ALL ON TABLE go_evidence_new_v12 FROM panther_isp;
GRANT ALL ON TABLE go_evidence_new_v12 TO panther_isp;
GRANT ALL ON TABLE go_evidence_new_v12 TO panther_upl;
GRANT ALL ON TABLE go_evidence_new_v12 TO panther_paint;


--
-- TOC entry 5124 (class 0 OID 0)
-- Dependencies: 488
-- Name: go_evidence_old; Type: ACL; Schema: panther_upl; Owner: panther_isp
--

REVOKE ALL ON TABLE go_evidence_old FROM PUBLIC;
REVOKE ALL ON TABLE go_evidence_old FROM panther_isp;
GRANT ALL ON TABLE go_evidence_old TO panther_isp;
GRANT ALL ON TABLE go_evidence_old TO panther_upl;
GRANT ALL ON TABLE go_evidence_old TO panther_paint;


--
-- TOC entry 5125 (class 0 OID 0)
-- Dependencies: 366
-- Name: go_isa; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE go_isa FROM PUBLIC;
REVOKE ALL ON TABLE go_isa FROM panther_upl;
GRANT ALL ON TABLE go_isa TO panther_upl;
GRANT ALL ON TABLE go_isa TO panther_users;
GRANT ALL ON TABLE go_isa TO panther_paint;


--
-- TOC entry 5126 (class 0 OID 0)
-- Dependencies: 480
-- Name: goanno_wf; Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON TABLE goanno_wf FROM PUBLIC;
REVOKE ALL ON TABLE goanno_wf FROM postgres;
GRANT ALL ON TABLE goanno_wf TO postgres;
GRANT ALL ON TABLE goanno_wf TO panther_paint;


--
-- TOC entry 5127 (class 0 OID 0)
-- Dependencies: 481
-- Name: gofoo_bp; Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON TABLE gofoo_bp FROM PUBLIC;
REVOKE ALL ON TABLE gofoo_bp FROM postgres;
GRANT ALL ON TABLE gofoo_bp TO postgres;
GRANT ALL ON TABLE gofoo_bp TO panther_paint;


--
-- TOC entry 5128 (class 0 OID 0)
-- Dependencies: 482
-- Name: gofoo_cc; Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON TABLE gofoo_cc FROM PUBLIC;
REVOKE ALL ON TABLE gofoo_cc FROM postgres;
GRANT ALL ON TABLE gofoo_cc TO postgres;
GRANT ALL ON TABLE gofoo_cc TO panther_paint;


--
-- TOC entry 5129 (class 0 OID 0)
-- Dependencies: 483
-- Name: gofoo_mf; Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON TABLE gofoo_mf FROM PUBLIC;
REVOKE ALL ON TABLE gofoo_mf FROM postgres;
GRANT ALL ON TABLE gofoo_mf TO postgres;
GRANT ALL ON TABLE gofoo_mf TO panther_paint;


--
-- TOC entry 5130 (class 0 OID 0)
-- Dependencies: 490
-- Name: goobo_parent_child; Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON TABLE goobo_parent_child FROM PUBLIC;
REVOKE ALL ON TABLE goobo_parent_child FROM postgres;
GRANT ALL ON TABLE goobo_parent_child TO postgres;
GRANT ALL ON TABLE goobo_parent_child TO panther_paint;


--
-- TOC entry 5131 (class 0 OID 0)
-- Dependencies: 367
-- Name: identifier; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE identifier FROM PUBLIC;
REVOKE ALL ON TABLE identifier FROM panther_upl;
GRANT ALL ON TABLE identifier TO panther_upl;
GRANT ALL ON TABLE identifier TO panther_users;
GRANT ALL ON TABLE identifier TO panther_paint;


--
-- TOC entry 5132 (class 0 OID 0)
-- Dependencies: 368
-- Name: identifier_type; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE identifier_type FROM PUBLIC;
REVOKE ALL ON TABLE identifier_type FROM panther_upl;
GRANT ALL ON TABLE identifier_type TO panther_upl;
GRANT ALL ON TABLE identifier_type TO panther_users;
GRANT ALL ON TABLE identifier_type TO panther_paint;


--
-- TOC entry 5133 (class 0 OID 0)
-- Dependencies: 369
-- Name: interpro2common; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE interpro2common FROM PUBLIC;
REVOKE ALL ON TABLE interpro2common FROM panther_upl;
GRANT ALL ON TABLE interpro2common TO panther_upl;
GRANT ALL ON TABLE interpro2common TO panther_users;
GRANT ALL ON TABLE interpro2common TO panther_paint;


--
-- TOC entry 5134 (class 0 OID 0)
-- Dependencies: 370
-- Name: interpro_curation_priority; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE interpro_curation_priority FROM PUBLIC;
REVOKE ALL ON TABLE interpro_curation_priority FROM panther_upl;
GRANT ALL ON TABLE interpro_curation_priority TO panther_upl;
GRANT ALL ON TABLE interpro_curation_priority TO panther_users;
GRANT ALL ON TABLE interpro_curation_priority TO panther_paint;


--
-- TOC entry 5135 (class 0 OID 0)
-- Dependencies: 371
-- Name: keyword_family_mapping; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE keyword_family_mapping FROM PUBLIC;
REVOKE ALL ON TABLE keyword_family_mapping FROM panther_upl;
GRANT ALL ON TABLE keyword_family_mapping TO panther_upl;
GRANT ALL ON TABLE keyword_family_mapping TO panther_users;
GRANT ALL ON TABLE keyword_family_mapping TO panther_paint;


--
-- TOC entry 5136 (class 0 OID 0)
-- Dependencies: 372
-- Name: keyword_type; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE keyword_type FROM PUBLIC;
REVOKE ALL ON TABLE keyword_type FROM panther_upl;
GRANT ALL ON TABLE keyword_type TO panther_upl;
GRANT ALL ON TABLE keyword_type TO panther_users;
GRANT ALL ON TABLE keyword_type TO panther_paint;


--
-- TOC entry 5137 (class 0 OID 0)
-- Dependencies: 373
-- Name: log_table; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE log_table FROM PUBLIC;
REVOKE ALL ON TABLE log_table FROM panther_upl;
GRANT ALL ON TABLE log_table TO panther_upl;
GRANT ALL ON TABLE log_table TO panther_users;
GRANT ALL ON TABLE log_table TO panther_paint;


--
-- TOC entry 5138 (class 0 OID 0)
-- Dependencies: 374
-- Name: most_specific_category; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE most_specific_category FROM PUBLIC;
REVOKE ALL ON TABLE most_specific_category FROM panther_upl;
GRANT ALL ON TABLE most_specific_category TO panther_upl;
GRANT ALL ON TABLE most_specific_category TO panther_users;
GRANT ALL ON TABLE most_specific_category TO panther_paint;


--
-- TOC entry 5139 (class 0 OID 0)
-- Dependencies: 375
-- Name: msa_detail; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE msa_detail FROM PUBLIC;
REVOKE ALL ON TABLE msa_detail FROM panther_upl;
GRANT ALL ON TABLE msa_detail TO panther_upl;
GRANT ALL ON TABLE msa_detail TO panther_users;
GRANT ALL ON TABLE msa_detail TO panther_paint;


--
-- TOC entry 5140 (class 0 OID 0)
-- Dependencies: 377
-- Name: node_name; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE node_name FROM PUBLIC;
REVOKE ALL ON TABLE node_name FROM panther_upl;
GRANT ALL ON TABLE node_name TO panther_upl;
GRANT ALL ON TABLE node_name TO panther_users;
GRANT ALL ON TABLE node_name TO panther_paint;


--
-- TOC entry 5141 (class 0 OID 0)
-- Dependencies: 477
-- Name: node_production; Type: ACL; Schema: panther_upl; Owner: postgres
--

REVOKE ALL ON TABLE node_production FROM PUBLIC;
REVOKE ALL ON TABLE node_production FROM postgres;
GRANT ALL ON TABLE node_production TO postgres;
GRANT ALL ON TABLE node_production TO panther_paint;


--
-- TOC entry 5142 (class 0 OID 0)
-- Dependencies: 378
-- Name: node_relationship; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE node_relationship FROM PUBLIC;
REVOKE ALL ON TABLE node_relationship FROM panther_upl;
GRANT ALL ON TABLE node_relationship TO panther_upl;
GRANT ALL ON TABLE node_relationship TO panther_users;
GRANT ALL ON TABLE node_relationship TO panther_paint;


--
-- TOC entry 5143 (class 0 OID 0)
-- Dependencies: 379
-- Name: node_type; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE node_type FROM PUBLIC;
REVOKE ALL ON TABLE node_type FROM panther_upl;
GRANT ALL ON TABLE node_type TO panther_upl;
GRANT ALL ON TABLE node_type TO panther_users;
GRANT ALL ON TABLE node_type TO panther_paint;


--
-- TOC entry 5144 (class 0 OID 0)
-- Dependencies: 380
-- Name: obsolete_cat_subfam; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE obsolete_cat_subfam FROM PUBLIC;
REVOKE ALL ON TABLE obsolete_cat_subfam FROM panther_upl;
GRANT ALL ON TABLE obsolete_cat_subfam TO panther_upl;
GRANT ALL ON TABLE obsolete_cat_subfam TO panther_users;
GRANT ALL ON TABLE obsolete_cat_subfam TO panther_paint;


--
-- TOC entry 5145 (class 0 OID 0)
-- Dependencies: 381
-- Name: organism; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE organism FROM PUBLIC;
REVOKE ALL ON TABLE organism FROM panther_upl;
GRANT ALL ON TABLE organism TO panther_upl;
GRANT ALL ON TABLE organism TO panther_users;
GRANT ALL ON TABLE organism TO panther_paint;


--
-- TOC entry 5146 (class 0 OID 0)
-- Dependencies: 688
-- Name: paint_annotation; Type: ACL; Schema: panther_upl; Owner: panther_isp
--

REVOKE ALL ON TABLE paint_annotation FROM PUBLIC;
REVOKE ALL ON TABLE paint_annotation FROM panther_isp;
GRANT ALL ON TABLE paint_annotation TO panther_isp;
GRANT ALL ON TABLE paint_annotation TO panther;
GRANT ALL ON TABLE paint_annotation TO panther_upl;
GRANT ALL ON TABLE paint_annotation TO panther_paint;


--
-- TOC entry 5147 (class 0 OID 0)
-- Dependencies: 676
-- Name: paint_annotation_forward_tracking; Type: ACL; Schema: panther_upl; Owner: panther_isp
--

REVOKE ALL ON TABLE paint_annotation_forward_tracking FROM PUBLIC;
REVOKE ALL ON TABLE paint_annotation_forward_tracking FROM panther_isp;
GRANT ALL ON TABLE paint_annotation_forward_tracking TO panther_isp;
GRANT ALL ON TABLE paint_annotation_forward_tracking TO panther;
GRANT ALL ON TABLE paint_annotation_forward_tracking TO panther_upl;
GRANT ALL ON TABLE paint_annotation_forward_tracking TO panther_paint;


--
-- TOC entry 5148 (class 0 OID 0)
-- Dependencies: 675
-- Name: paint_annotation_new_v12; Type: ACL; Schema: panther_upl; Owner: panther_isp
--

REVOKE ALL ON TABLE paint_annotation_new_v12 FROM PUBLIC;
REVOKE ALL ON TABLE paint_annotation_new_v12 FROM panther_isp;
GRANT ALL ON TABLE paint_annotation_new_v12 TO panther_isp;
GRANT ALL ON TABLE paint_annotation_new_v12 TO panther;
GRANT ALL ON TABLE paint_annotation_new_v12 TO panther_upl;
GRANT ALL ON TABLE paint_annotation_new_v12 TO panther_paint;


--
-- TOC entry 5149 (class 0 OID 0)
-- Dependencies: 474
-- Name: paint_annotation_old; Type: ACL; Schema: panther_upl; Owner: panther_isp
--

REVOKE ALL ON TABLE paint_annotation_old FROM PUBLIC;
REVOKE ALL ON TABLE paint_annotation_old FROM panther_isp;
GRANT ALL ON TABLE paint_annotation_old TO panther_isp;
GRANT ALL ON TABLE paint_annotation_old TO panther;
GRANT ALL ON TABLE paint_annotation_old TO panther_upl;
GRANT ALL ON TABLE paint_annotation_old TO panther_paint;


--
-- TOC entry 5150 (class 0 OID 0)
-- Dependencies: 476
-- Name: paint_annotation_qualifier; Type: ACL; Schema: panther_upl; Owner: panther_isp
--

REVOKE ALL ON TABLE paint_annotation_qualifier FROM PUBLIC;
REVOKE ALL ON TABLE paint_annotation_qualifier FROM panther_isp;
GRANT ALL ON TABLE paint_annotation_qualifier TO panther_isp;
GRANT ALL ON TABLE paint_annotation_qualifier TO panther;
GRANT ALL ON TABLE paint_annotation_qualifier TO panther_upl;
GRANT ALL ON TABLE paint_annotation_qualifier TO panther_paint;


--
-- TOC entry 5151 (class 0 OID 0)
-- Dependencies: 682
-- Name: paint_annotation_qualifier_new_v12; Type: ACL; Schema: panther_upl; Owner: panther_isp
--

REVOKE ALL ON TABLE paint_annotation_qualifier_new_v12 FROM PUBLIC;
REVOKE ALL ON TABLE paint_annotation_qualifier_new_v12 FROM panther_isp;
GRANT ALL ON TABLE paint_annotation_qualifier_new_v12 TO panther_isp;
GRANT ALL ON TABLE paint_annotation_qualifier_new_v12 TO panther;
GRANT ALL ON TABLE paint_annotation_qualifier_new_v12 TO panther_upl;
GRANT ALL ON TABLE paint_annotation_qualifier_new_v12 TO panther_paint;


--
-- TOC entry 5152 (class 0 OID 0)
-- Dependencies: 475
-- Name: paint_evidence; Type: ACL; Schema: panther_upl; Owner: panther_isp
--

REVOKE ALL ON TABLE paint_evidence FROM PUBLIC;
REVOKE ALL ON TABLE paint_evidence FROM panther_isp;
GRANT ALL ON TABLE paint_evidence TO panther_isp;
GRANT ALL ON TABLE paint_evidence TO panther;
GRANT ALL ON TABLE paint_evidence TO panther_upl;
GRANT ALL ON TABLE paint_evidence TO panther_paint;


--
-- TOC entry 5153 (class 0 OID 0)
-- Dependencies: 678
-- Name: paint_evidence_new_v12; Type: ACL; Schema: panther_upl; Owner: panther_isp
--

REVOKE ALL ON TABLE paint_evidence_new_v12 FROM PUBLIC;
REVOKE ALL ON TABLE paint_evidence_new_v12 FROM panther_isp;
GRANT ALL ON TABLE paint_evidence_new_v12 TO panther_isp;
GRANT ALL ON TABLE paint_evidence_new_v12 TO panther;
GRANT ALL ON TABLE paint_evidence_new_v12 TO panther_upl;
GRANT ALL ON TABLE paint_evidence_new_v12 TO panther_paint;


--
-- TOC entry 5154 (class 0 OID 0)
-- Dependencies: 689
-- Name: paint_evidence_old; Type: ACL; Schema: panther_upl; Owner: panther_isp
--

REVOKE ALL ON TABLE paint_evidence_old FROM PUBLIC;
REVOKE ALL ON TABLE paint_evidence_old FROM panther_isp;
GRANT ALL ON TABLE paint_evidence_old TO panther_isp;
GRANT ALL ON TABLE paint_evidence_old TO panther;
GRANT ALL ON TABLE paint_evidence_old TO panther_upl;
GRANT ALL ON TABLE paint_evidence_old TO panther_paint;


--
-- TOC entry 5155 (class 0 OID 0)
-- Dependencies: 382
-- Name: panther_to_interpro; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE panther_to_interpro FROM PUBLIC;
REVOKE ALL ON TABLE panther_to_interpro FROM panther_upl;
GRANT ALL ON TABLE panther_to_interpro TO panther_upl;
GRANT ALL ON TABLE panther_to_interpro TO panther_users;
GRANT ALL ON TABLE panther_to_interpro TO panther_paint;


--
-- TOC entry 5156 (class 0 OID 0)
-- Dependencies: 383
-- Name: pathway_category_book_visited; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE pathway_category_book_visited FROM PUBLIC;
REVOKE ALL ON TABLE pathway_category_book_visited FROM panther_upl;
GRANT ALL ON TABLE pathway_category_book_visited TO panther_upl;
GRANT ALL ON TABLE pathway_category_book_visited TO panther_users;
GRANT ALL ON TABLE pathway_category_book_visited TO panther_paint;


--
-- TOC entry 5157 (class 0 OID 0)
-- Dependencies: 384
-- Name: pathway_category_info; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE pathway_category_info FROM PUBLIC;
REVOKE ALL ON TABLE pathway_category_info FROM panther_upl;
GRANT ALL ON TABLE pathway_category_info TO panther_upl;
GRANT ALL ON TABLE pathway_category_info TO panther_users;
GRANT ALL ON TABLE pathway_category_info TO panther_paint;


--
-- TOC entry 5158 (class 0 OID 0)
-- Dependencies: 385
-- Name: pathway_category_relation; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE pathway_category_relation FROM PUBLIC;
REVOKE ALL ON TABLE pathway_category_relation FROM panther_upl;
GRANT ALL ON TABLE pathway_category_relation TO panther_upl;
GRANT ALL ON TABLE pathway_category_relation TO panther_users;
GRANT ALL ON TABLE pathway_category_relation TO panther_paint;


--
-- TOC entry 5159 (class 0 OID 0)
-- Dependencies: 386
-- Name: pathway_curation; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE pathway_curation FROM PUBLIC;
REVOKE ALL ON TABLE pathway_curation FROM panther_upl;
GRANT ALL ON TABLE pathway_curation TO panther_upl;
GRANT ALL ON TABLE pathway_curation TO panther_users;
GRANT ALL ON TABLE pathway_curation TO panther_paint;


--
-- TOC entry 5160 (class 0 OID 0)
-- Dependencies: 387
-- Name: pathway_keyword_search; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE pathway_keyword_search FROM PUBLIC;
REVOKE ALL ON TABLE pathway_keyword_search FROM panther_upl;
GRANT ALL ON TABLE pathway_keyword_search TO panther_upl;
GRANT ALL ON TABLE pathway_keyword_search TO panther_users;
GRANT ALL ON TABLE pathway_keyword_search TO panther_paint;


--
-- TOC entry 5161 (class 0 OID 0)
-- Dependencies: 388
-- Name: pathway_keyword_search_10; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE pathway_keyword_search_10 FROM PUBLIC;
REVOKE ALL ON TABLE pathway_keyword_search_10 FROM panther_upl;
GRANT ALL ON TABLE pathway_keyword_search_10 TO panther_upl;
GRANT ALL ON TABLE pathway_keyword_search_10 TO panther_users;
GRANT ALL ON TABLE pathway_keyword_search_10 TO panther_paint;


--
-- TOC entry 5162 (class 0 OID 0)
-- Dependencies: 389
-- Name: pathway_keyword_search_11; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE pathway_keyword_search_11 FROM PUBLIC;
REVOKE ALL ON TABLE pathway_keyword_search_11 FROM panther_upl;
GRANT ALL ON TABLE pathway_keyword_search_11 TO panther_upl;
GRANT ALL ON TABLE pathway_keyword_search_11 TO panther_users;
GRANT ALL ON TABLE pathway_keyword_search_11 TO panther_paint;


--
-- TOC entry 5163 (class 0 OID 0)
-- Dependencies: 390
-- Name: pathway_xmlfile_lookup; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE pathway_xmlfile_lookup FROM PUBLIC;
REVOKE ALL ON TABLE pathway_xmlfile_lookup FROM panther_upl;
GRANT ALL ON TABLE pathway_xmlfile_lookup TO panther_upl;
GRANT ALL ON TABLE pathway_xmlfile_lookup TO panther_users;
GRANT ALL ON TABLE pathway_xmlfile_lookup TO panther_paint;


--
-- TOC entry 5164 (class 0 OID 0)
-- Dependencies: 391
-- Name: pc_qualifier; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE pc_qualifier FROM PUBLIC;
REVOKE ALL ON TABLE pc_qualifier FROM panther_upl;
GRANT ALL ON TABLE pc_qualifier TO panther_upl;
GRANT ALL ON TABLE pc_qualifier TO panther_users;
GRANT ALL ON TABLE pc_qualifier TO panther_paint;


--
-- TOC entry 5165 (class 0 OID 0)
-- Dependencies: 392
-- Name: previous_upl_info; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE previous_upl_info FROM PUBLIC;
REVOKE ALL ON TABLE previous_upl_info FROM panther_upl;
GRANT ALL ON TABLE previous_upl_info TO panther_upl;
GRANT ALL ON TABLE previous_upl_info TO panther_users;
GRANT ALL ON TABLE previous_upl_info TO panther_paint;


--
-- TOC entry 5166 (class 0 OID 0)
-- Dependencies: 393
-- Name: prot_temp_sixone; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE prot_temp_sixone FROM PUBLIC;
REVOKE ALL ON TABLE prot_temp_sixone FROM panther_upl;
GRANT ALL ON TABLE prot_temp_sixone TO panther_upl;
GRANT ALL ON TABLE prot_temp_sixone TO panther_users;
GRANT ALL ON TABLE prot_temp_sixone TO panther_paint;


--
-- TOC entry 5167 (class 0 OID 0)
-- Dependencies: 394
-- Name: protein; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE protein FROM PUBLIC;
REVOKE ALL ON TABLE protein FROM panther_upl;
GRANT ALL ON TABLE protein TO panther_upl;
GRANT ALL ON TABLE protein TO panther_users;
GRANT ALL ON TABLE protein TO panther_paint;


--
-- TOC entry 5168 (class 0 OID 0)
-- Dependencies: 395
-- Name: protein_classification; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE protein_classification FROM PUBLIC;
REVOKE ALL ON TABLE protein_classification FROM panther_upl;
GRANT ALL ON TABLE protein_classification TO panther_upl;
GRANT ALL ON TABLE protein_classification TO panther_users;
GRANT ALL ON TABLE protein_classification TO panther_paint;


--
-- TOC entry 5169 (class 0 OID 0)
-- Dependencies: 396
-- Name: protein_info; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE protein_info FROM PUBLIC;
REVOKE ALL ON TABLE protein_info FROM panther_upl;
GRANT ALL ON TABLE protein_info TO panther_upl;
GRANT ALL ON TABLE protein_info TO panther_users;
GRANT ALL ON TABLE protein_info TO panther_paint;


--
-- TOC entry 5170 (class 0 OID 0)
-- Dependencies: 397
-- Name: protein_mapping; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE protein_mapping FROM PUBLIC;
REVOKE ALL ON TABLE protein_mapping FROM panther_upl;
GRANT ALL ON TABLE protein_mapping TO panther_upl;
GRANT ALL ON TABLE protein_mapping TO panther_users;
GRANT ALL ON TABLE protein_mapping TO panther_paint;


--
-- TOC entry 5171 (class 0 OID 0)
-- Dependencies: 398
-- Name: protein_node; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE protein_node FROM PUBLIC;
REVOKE ALL ON TABLE protein_node FROM panther_upl;
GRANT ALL ON TABLE protein_node TO panther_upl;
GRANT ALL ON TABLE protein_node TO panther_users;
GRANT ALL ON TABLE protein_node TO panther_paint;


--
-- TOC entry 5172 (class 0 OID 0)
-- Dependencies: 399
-- Name: protein_source; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE protein_source FROM PUBLIC;
REVOKE ALL ON TABLE protein_source FROM panther_upl;
GRANT ALL ON TABLE protein_source TO panther_upl;
GRANT ALL ON TABLE protein_source TO panther_users;
GRANT ALL ON TABLE protein_source TO panther_paint;


--
-- TOC entry 5173 (class 0 OID 0)
-- Dependencies: 401
-- Name: relationship_type; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE relationship_type FROM PUBLIC;
REVOKE ALL ON TABLE relationship_type FROM panther_upl;
GRANT ALL ON TABLE relationship_type TO panther_upl;
GRANT ALL ON TABLE relationship_type TO panther_users;
GRANT ALL ON TABLE relationship_type TO panther_paint;


--
-- TOC entry 5174 (class 0 OID 0)
-- Dependencies: 402
-- Name: score; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE score FROM PUBLIC;
REVOKE ALL ON TABLE score FROM panther_upl;
GRANT ALL ON TABLE score TO panther_upl;
GRANT ALL ON TABLE score TO panther_users;
GRANT ALL ON TABLE score TO panther_paint;


--
-- TOC entry 5175 (class 0 OID 0)
-- Dependencies: 403
-- Name: score_type; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE score_type FROM PUBLIC;
REVOKE ALL ON TABLE score_type FROM panther_upl;
GRANT ALL ON TABLE score_type TO panther_upl;
GRANT ALL ON TABLE score_type TO panther_users;
GRANT ALL ON TABLE score_type TO panther_paint;


--
-- TOC entry 5176 (class 0 OID 0)
-- Dependencies: 404
-- Name: seq_info; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE seq_info FROM PUBLIC;
REVOKE ALL ON TABLE seq_info FROM panther_upl;
GRANT ALL ON TABLE seq_info TO panther_upl;
GRANT ALL ON TABLE seq_info TO panther_users;
GRANT ALL ON TABLE seq_info TO panther_paint;


--
-- TOC entry 5177 (class 0 OID 0)
-- Dependencies: 405
-- Name: sequence_mapto_prev_version; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE sequence_mapto_prev_version FROM PUBLIC;
REVOKE ALL ON TABLE sequence_mapto_prev_version FROM panther_upl;
GRANT ALL ON TABLE sequence_mapto_prev_version TO panther_upl;
GRANT ALL ON TABLE sequence_mapto_prev_version TO panther_users;
GRANT ALL ON TABLE sequence_mapto_prev_version TO panther_paint;


--
-- TOC entry 5178 (class 0 OID 0)
-- Dependencies: 406
-- Name: subfam_category; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE subfam_category FROM PUBLIC;
REVOKE ALL ON TABLE subfam_category FROM panther_upl;
GRANT ALL ON TABLE subfam_category TO panther_upl;
GRANT ALL ON TABLE subfam_category TO panther_users;
GRANT ALL ON TABLE subfam_category TO panther_paint;


--
-- TOC entry 5179 (class 0 OID 0)
-- Dependencies: 407
-- Name: subfam_category_hierarchy; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE subfam_category_hierarchy FROM PUBLIC;
REVOKE ALL ON TABLE subfam_category_hierarchy FROM panther_upl;
GRANT ALL ON TABLE subfam_category_hierarchy TO panther_upl;
GRANT ALL ON TABLE subfam_category_hierarchy TO panther_users;
GRANT ALL ON TABLE subfam_category_hierarchy TO panther_paint;


--
-- TOC entry 5180 (class 0 OID 0)
-- Dependencies: 408
-- Name: subfam_seq_info; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE subfam_seq_info FROM PUBLIC;
REVOKE ALL ON TABLE subfam_seq_info FROM panther_upl;
GRANT ALL ON TABLE subfam_seq_info TO panther_upl;
GRANT ALL ON TABLE subfam_seq_info TO panther_users;
GRANT ALL ON TABLE subfam_seq_info TO panther_paint;


--
-- TOC entry 5181 (class 0 OID 0)
-- Dependencies: 409
-- Name: subfam_seq_relation; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE subfam_seq_relation FROM PUBLIC;
REVOKE ALL ON TABLE subfam_seq_relation FROM panther_upl;
GRANT ALL ON TABLE subfam_seq_relation TO panther_upl;
GRANT ALL ON TABLE subfam_seq_relation TO panther_users;
GRANT ALL ON TABLE subfam_seq_relation TO panther_paint;


--
-- TOC entry 5182 (class 0 OID 0)
-- Dependencies: 410
-- Name: subfamily_keyword; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE subfamily_keyword FROM PUBLIC;
REVOKE ALL ON TABLE subfamily_keyword FROM panther_upl;
GRANT ALL ON TABLE subfamily_keyword TO panther_upl;
GRANT ALL ON TABLE subfamily_keyword TO panther_users;
GRANT ALL ON TABLE subfamily_keyword TO panther_paint;


--
-- TOC entry 5183 (class 0 OID 0)
-- Dependencies: 411
-- Name: subfamily_organism; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE subfamily_organism FROM PUBLIC;
REVOKE ALL ON TABLE subfamily_organism FROM panther_upl;
GRANT ALL ON TABLE subfamily_organism TO panther_upl;
GRANT ALL ON TABLE subfamily_organism TO panther_users;
GRANT ALL ON TABLE subfamily_organism TO panther_paint;


--
-- TOC entry 5184 (class 0 OID 0)
-- Dependencies: 412
-- Name: subfamily_reorder; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE subfamily_reorder FROM PUBLIC;
REVOKE ALL ON TABLE subfamily_reorder FROM panther_upl;
GRANT ALL ON TABLE subfamily_reorder TO panther_upl;
GRANT ALL ON TABLE subfamily_reorder TO panther_users;
GRANT ALL ON TABLE subfamily_reorder TO panther_paint;


--
-- TOC entry 5185 (class 0 OID 0)
-- Dependencies: 413
-- Name: taxonomy; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE taxonomy FROM PUBLIC;
REVOKE ALL ON TABLE taxonomy FROM panther_upl;
GRANT ALL ON TABLE taxonomy TO panther_upl;
GRANT ALL ON TABLE taxonomy TO panther_users;
GRANT ALL ON TABLE taxonomy TO panther_paint;


--
-- TOC entry 5186 (class 0 OID 0)
-- Dependencies: 414
-- Name: temp; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE temp FROM PUBLIC;
REVOKE ALL ON TABLE temp FROM panther_upl;
GRANT ALL ON TABLE temp TO panther_upl;
GRANT ALL ON TABLE temp TO panther_users;
GRANT ALL ON TABLE temp TO panther_paint;


--
-- TOC entry 5187 (class 0 OID 0)
-- Dependencies: 415
-- Name: temp_cat_level1; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE temp_cat_level1 FROM PUBLIC;
REVOKE ALL ON TABLE temp_cat_level1 FROM panther_upl;
GRANT ALL ON TABLE temp_cat_level1 TO panther_upl;
GRANT ALL ON TABLE temp_cat_level1 TO panther_users;
GRANT ALL ON TABLE temp_cat_level1 TO panther_paint;


--
-- TOC entry 5188 (class 0 OID 0)
-- Dependencies: 416
-- Name: temp_category_relation_only; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE temp_category_relation_only FROM PUBLIC;
REVOKE ALL ON TABLE temp_category_relation_only FROM panther_upl;
GRANT ALL ON TABLE temp_category_relation_only TO panther_upl;
GRANT ALL ON TABLE temp_category_relation_only TO panther_users;
GRANT ALL ON TABLE temp_category_relation_only TO panther_paint;


--
-- TOC entry 5189 (class 0 OID 0)
-- Dependencies: 417
-- Name: temp_cats; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE temp_cats FROM PUBLIC;
REVOKE ALL ON TABLE temp_cats FROM panther_upl;
GRANT ALL ON TABLE temp_cats TO panther_upl;
GRANT ALL ON TABLE temp_cats TO panther_users;
GRANT ALL ON TABLE temp_cats TO panther_paint;


--
-- TOC entry 5190 (class 0 OID 0)
-- Dependencies: 418
-- Name: temp_common_annotation_block; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE temp_common_annotation_block FROM PUBLIC;
REVOKE ALL ON TABLE temp_common_annotation_block FROM panther_upl;
GRANT ALL ON TABLE temp_common_annotation_block TO panther_upl;
GRANT ALL ON TABLE temp_common_annotation_block TO panther_users;
GRANT ALL ON TABLE temp_common_annotation_block TO panther_paint;


--
-- TOC entry 5191 (class 0 OID 0)
-- Dependencies: 419
-- Name: temp_family_category; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE temp_family_category FROM PUBLIC;
REVOKE ALL ON TABLE temp_family_category FROM panther_upl;
GRANT ALL ON TABLE temp_family_category TO panther_upl;
GRANT ALL ON TABLE temp_family_category TO panther_users;
GRANT ALL ON TABLE temp_family_category TO panther_paint;


--
-- TOC entry 5192 (class 0 OID 0)
-- Dependencies: 420
-- Name: temp_level1; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE temp_level1 FROM PUBLIC;
REVOKE ALL ON TABLE temp_level1 FROM panther_upl;
GRANT ALL ON TABLE temp_level1 TO panther_upl;
GRANT ALL ON TABLE temp_level1 TO panther_users;
GRANT ALL ON TABLE temp_level1 TO panther_paint;


--
-- TOC entry 5193 (class 0 OID 0)
-- Dependencies: 421
-- Name: temp_level1_level2; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE temp_level1_level2 FROM PUBLIC;
REVOKE ALL ON TABLE temp_level1_level2 FROM panther_upl;
GRANT ALL ON TABLE temp_level1_level2 TO panther_upl;
GRANT ALL ON TABLE temp_level1_level2 TO panther_users;
GRANT ALL ON TABLE temp_level1_level2 TO panther_paint;


--
-- TOC entry 5194 (class 0 OID 0)
-- Dependencies: 422
-- Name: temp_level1_level2_level3; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE temp_level1_level2_level3 FROM PUBLIC;
REVOKE ALL ON TABLE temp_level1_level2_level3 FROM panther_upl;
GRANT ALL ON TABLE temp_level1_level2_level3 TO panther_upl;
GRANT ALL ON TABLE temp_level1_level2_level3 TO panther_users;
GRANT ALL ON TABLE temp_level1_level2_level3 TO panther_paint;


--
-- TOC entry 5195 (class 0 OID 0)
-- Dependencies: 423
-- Name: temp_pathway_association; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE temp_pathway_association FROM PUBLIC;
REVOKE ALL ON TABLE temp_pathway_association FROM panther_upl;
GRANT ALL ON TABLE temp_pathway_association TO panther_upl;
GRANT ALL ON TABLE temp_pathway_association TO panther_users;
GRANT ALL ON TABLE temp_pathway_association TO panther_paint;


--
-- TOC entry 5196 (class 0 OID 0)
-- Dependencies: 424
-- Name: temp_sf_reorder; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE temp_sf_reorder FROM PUBLIC;
REVOKE ALL ON TABLE temp_sf_reorder FROM panther_upl;
GRANT ALL ON TABLE temp_sf_reorder TO panther_upl;
GRANT ALL ON TABLE temp_sf_reorder TO panther_users;
GRANT ALL ON TABLE temp_sf_reorder TO panther_paint;


--
-- TOC entry 5197 (class 0 OID 0)
-- Dependencies: 425
-- Name: temp_subfamily_category; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE temp_subfamily_category FROM PUBLIC;
REVOKE ALL ON TABLE temp_subfamily_category FROM panther_upl;
GRANT ALL ON TABLE temp_subfamily_category TO panther_upl;
GRANT ALL ON TABLE temp_subfamily_category TO panther_users;
GRANT ALL ON TABLE temp_subfamily_category TO panther_paint;


--
-- TOC entry 5198 (class 0 OID 0)
-- Dependencies: 426
-- Name: temp_subfamily_category_count; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE temp_subfamily_category_count FROM PUBLIC;
REVOKE ALL ON TABLE temp_subfamily_category_count FROM panther_upl;
GRANT ALL ON TABLE temp_subfamily_category_count TO panther_upl;
GRANT ALL ON TABLE temp_subfamily_category_count TO panther_users;
GRANT ALL ON TABLE temp_subfamily_category_count TO panther_paint;


--
-- TOC entry 5199 (class 0 OID 0)
-- Dependencies: 427
-- Name: temp_uniprot_score; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE temp_uniprot_score FROM PUBLIC;
REVOKE ALL ON TABLE temp_uniprot_score FROM panther_upl;
GRANT ALL ON TABLE temp_uniprot_score TO panther_upl;
GRANT ALL ON TABLE temp_uniprot_score TO panther_users;
GRANT ALL ON TABLE temp_uniprot_score TO panther_paint;


--
-- TOC entry 5200 (class 0 OID 0)
-- Dependencies: 428
-- Name: test_new_books; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE test_new_books FROM PUBLIC;
REVOKE ALL ON TABLE test_new_books FROM panther_upl;
GRANT ALL ON TABLE test_new_books TO panther_upl;
GRANT ALL ON TABLE test_new_books TO panther_users;
GRANT ALL ON TABLE test_new_books TO panther_paint;


--
-- TOC entry 5201 (class 0 OID 0)
-- Dependencies: 429
-- Name: tmp; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE tmp FROM PUBLIC;
REVOKE ALL ON TABLE tmp FROM panther_upl;
GRANT ALL ON TABLE tmp TO panther_upl;
GRANT ALL ON TABLE tmp TO panther_users;
GRANT ALL ON TABLE tmp TO panther_paint;


--
-- TOC entry 5202 (class 0 OID 0)
-- Dependencies: 430
-- Name: tree_detail; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE tree_detail FROM PUBLIC;
REVOKE ALL ON TABLE tree_detail FROM panther_upl;
GRANT ALL ON TABLE tree_detail TO panther_upl;
GRANT ALL ON TABLE tree_detail TO panther_users;
GRANT ALL ON TABLE tree_detail TO panther_paint;


--
-- TOC entry 5203 (class 0 OID 0)
-- Dependencies: 438
-- Name: uids; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON SEQUENCE uids FROM PUBLIC;
REVOKE ALL ON SEQUENCE uids FROM panther_upl;
GRANT ALL ON SEQUENCE uids TO panther_upl;
GRANT ALL ON SEQUENCE uids TO panther_users;


--
-- TOC entry 5204 (class 0 OID 0)
-- Dependencies: 431
-- Name: upl_book_visited; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE upl_book_visited FROM PUBLIC;
REVOKE ALL ON TABLE upl_book_visited FROM panther_upl;
GRANT ALL ON TABLE upl_book_visited TO panther_upl;
GRANT ALL ON TABLE upl_book_visited TO panther_users;
GRANT ALL ON TABLE upl_book_visited TO panther_paint;


--
-- TOC entry 5205 (class 0 OID 0)
-- Dependencies: 432
-- Name: users; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE users FROM PUBLIC;
REVOKE ALL ON TABLE users FROM panther_upl;
GRANT ALL ON TABLE users TO panther_upl;
GRANT ALL ON TABLE users TO panther_users;
GRANT ALL ON TABLE users TO panther_paint;


--
-- TOC entry 5206 (class 0 OID 0)
-- Dependencies: 433
-- Name: valid_organism; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE valid_organism FROM PUBLIC;
REVOKE ALL ON TABLE valid_organism FROM panther_upl;
GRANT ALL ON TABLE valid_organism TO panther_upl;
GRANT ALL ON TABLE valid_organism TO panther_users;
GRANT ALL ON TABLE valid_organism TO panther_paint;


--
-- TOC entry 5207 (class 0 OID 0)
-- Dependencies: 434
-- Name: view_protein_classification; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE view_protein_classification FROM PUBLIC;
REVOKE ALL ON TABLE view_protein_classification FROM panther_upl;
GRANT ALL ON TABLE view_protein_classification TO panther_upl;
GRANT ALL ON TABLE view_protein_classification TO panther_users;
GRANT ALL ON TABLE view_protein_classification TO panther_paint;


--
-- TOC entry 5208 (class 0 OID 0)
-- Dependencies: 435
-- Name: view_protein_classification_1; Type: ACL; Schema: panther_upl; Owner: panther_upl
--

REVOKE ALL ON TABLE view_protein_classification_1 FROM PUBLIC;
REVOKE ALL ON TABLE view_protein_classification_1 FROM panther_upl;
GRANT ALL ON TABLE view_protein_classification_1 TO panther_upl;
GRANT ALL ON TABLE view_protein_classification_1 TO panther_users;
GRANT ALL ON TABLE view_protein_classification_1 TO panther_paint;


-- Completed on 2017-05-01 10:55:19

--
-- PostgreSQL database dump complete
--

