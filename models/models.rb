# require_relative 'base'

def check_limit_offset(params)
  %i(limit offset).each do |p|
    unless params[p].nil?
      begin
        params[p] = Integer(params[p])
      rescue ArgumentError
        raise Exception.new("#{p.to_s} is not an integer")
      end
    end
  end
  return params
end

# module Models
#   def self.models
#     constants.select { |c| const_get(c).is_a?(Class) }
#   end

#   # class PlotMetadata < Base
#   #   self.table_name = 'plot_metadata'
#   #   self.req_field = 'plot_metadata_id'
#   # end
# end

class List < ActiveRecord::Base
  self.table_name = 'bien_species_all'

  def self.endpoint(params)
    params.delete_if { |k, v| v.nil? || v.empty? }
    params = check_limit_offset(params)
    raise Exception.new('limit too large (max 1000)') unless (params[:limit] || 0) <= 1000
    select('species')
      .order('species')
      .limit(params[:limit] || 10)
      .offset(params[:offset])
  end
end

class ListCountry < ActiveRecord::Base
  self.table_name = 'species_by_political_division'

  def self.endpoint(params)
    params.delete_if { |k, v| v.nil? || v.empty? }
    params = check_limit_offset(params)
    raise Exception.new('limit too large (max 1000)') unless (params[:limit] || 0) <= 1000
    select('country, scrubbed_species_binomial').distinct
          .order(:scrubbed_species_binomial)
          .where(sprintf("country in ('%s')
            AND scrubbed_species_binomial IS NOT NULL
            AND (is_cultivated_in_region = 0 OR is_cultivated_in_region IS NULL)
            AND is_new_world = 1", params[:country]))
          .limit(params[:limit] || 10)
          .offset(params[:offset])
  end
end

class PlotMetadata < ActiveRecord::Base
  self.table_name = 'plot_metadata'

  def self.endpoint(params)
    req_field = 'plot_metadata_id'
    params.delete_if { |k, v| v.nil? || v.empty? }
    params = check_limit_offset(params)
    raise Exception.new('limit too large (max 1000)') unless (params[:limit] || 0) <= 1000
    fields = params[:fields].nil? ? req_field : req_field.concat(',') + params[:fields]
    limit(params[:limit] || 10)
        .offset(params[:offset])
        .select(fields)
  end
end

class PlotProtocols < ActiveRecord::Base
  self.table_name = 'plot_metadata'

  def self.endpoint
    select(:sampling_protocol).distinct()
  end
end

# class PlotSamplingProtocol < ActiveRecord::Base
#   self.table_name = 'plot_metadata'

#   def self.endpoint(params)
#     req_field = 'plot_metadata_id'
#     params.delete_if { |k, v| v.nil? || v.empty? }
#     params = check_limit_offset(params)
#     raise Exception.new('limit too large (max 1000)') unless (params[:limit] || 0) <= 1000
#     fields = params[:fields].nil? ? req_field : req_field.concat(',') + params[:fields]
#     limit(params[:limit] || 10)
#         .offset(params[:offset])
#         .select(fields)
#   end
# end

# class PlotName < ActiveRecord::Base
#   self.table_name = 'view_full_occurrence_individual'

#   def self.endpoint(params)
#     params.delete_if { |k, v| v.nil? || v.empty? }
#     params = check_limit_offset(params)
#     raise Exception.new('limit too large (max 1000)') unless (params[:limit] || 0) <= 1000
#     cols = %w(view_full_occurrence_individual.plot_name subplot view_full_occurrence_individual.elevation_m  view_full_occurrence_individual.plot_area_ha
#       view_full_occurrence_individual.sampling_protocol view_full_occurrence_individual.recorded_by  view_full_occurrence_individual.scrubbed_species_binomial
#       view_full_occurrence_individual.individual_count view_full_occurrence_individual.latitude  view_full_occurrence_individual.longitude view_full_occurrence_individual.date_collected
#       view_full_occurrence_individual.datasource view_full_occurrence_individual.dataset view_full_occurrence_individual.dataowner
#       view_full_occurrence_individual.custodial_institution_codes collection_code view_full_occurrence_individual.datasource_id
#     )
#     select(cols.join(', '))
#       # .select("(SELECT * FROM view_full_occurrence_individual WHERE view_full_occurrence_individual.plot_name in ( :plot )
#       #       AND higher_plant_group IS NOT NULL
#       #       AND (is_geovalid = 1 OR is_geovalid IS NULL)
#       #       AND observation_type='plot'
#       #       ORDER BY country,plot_name,subplot,scrubbed_species_binomial) as view_full_occurrence_individual", {plot: params[:plot]})
#       # .joins("LEFT JOIN plot_metadata ON (view_full_occurrence_individual.plot_metadata_id=plot_metadata.plot_metadata_id)")
#       # .limit(params[:limit] || 10)
#       # .offset(params[:offset])
#       .where("view_full_occurrence_individual.plot_name in ( :plot )
#               AND higher_plant_group IS NOT NULL
#               AND (is_geovalid = 1 OR is_geovalid IS NULL)
#               AND observation_type='plot'
#               ORDER BY country,plot_name,subplot,scrubbed_species_binomial as view_full_occurrence_individual", {plot: params[:plot]})
#         .joins("LEFT JOIN plot_metadata ON (view_full_occurrence_individual.plot_metadata_id=plot_metadata.plot_metadata_id)")
#         .limit(params[:limit] || 10)
#         .offset(params[:offset])
#   end
# end

class TaxonomySpecies < ActiveRecord::Base
  self.table_name = 'bien_taxonomy'

  def self.endpoint(params)
    params.delete_if { |k, v| v.nil? || v.empty? }
    params = check_limit_offset(params)
    raise Exception.new('limit too large (max 1000)') unless (params[:limit] || 0) <= 1000
    sel1 = %w(higher_plant_group "class" superorder "order" scrubbed_family scrubbed_genus
      scrubbed_species_binomial scrubbed_author scrubbed_taxonomic_status)
    ord1 = %w(higher_plant_group scrubbed_family scrubbed_genus scrubbed_species_binomial scrubbed_author)
    select(sel1.join(', '))
        .distinct()
        .where(sprintf("scrubbed_species_binomial in ('%s')
           AND scrubbed_species_binomial IS NOT NULL", params[:species]))
        .order(ord1.join(', '))
        .limit(params[:limit] || 10)
        .offset(params[:offset])
  end
end

# SELECT DISTINCT 
#   higher_plant_group, "class", superorder, "order", scrubbed_family,
#   scrubbed_genus,scrubbed_species_binomial,scrubbed_author,scrubbed_taxonomic_status  
# FROM bien_taxonomy  
# WHERE scrubbed_species_binomial in ( 'Acer nigrum' ) 
# AND scrubbed_species_binomial IS NOT NULL  
# ORDER BY higher_plant_group,scrubbed_family,scrubbed_genus,scrubbed_species_binomial,scrubbed_author

class Traits < ActiveRecord::Base
  self.table_name = 'agg_traits'

  def self.endpoint(params)
    params.delete_if { |k, v| v.nil? || v.empty? }
    params = check_limit_offset(params)
    raise Exception.new('limit too large (max 1000)') unless (params[:limit] || 0) <= 1000
    select("trait_name")
        .distinct()
        .order("trait_name")
        .limit(params[:limit] || 10)
        .offset(params[:offset])
  end
end

class TraitsFamily < ActiveRecord::Base
  self.table_name = 'agg_traits'

  def self.endpoint(params)
    params.delete_if { |k, v| v.nil? || v.empty? }
    params = check_limit_offset(params)
    raise Exception.new('limit too large (max 1000)') unless (params[:limit] || 0) <= 1000
    cols = %w(scrubbed_family scrubbed_genus scrubbed_species_binomial trait_name trait_value unit method latitude longitude elevation url_source project_pi project_pi_contact access id)
    select(cols.join(', '))
        .where(sprintf("scrubbed_family in ( '%s' )", params[:family]))
        .order("scrubbed_family, scrubbed_species_binomial")
        .limit(params[:limit] || 10)
        .offset(params[:offset])
  end
end

class OccurrenceSpecies < ActiveRecord::Base
  self.table_name = 'view_full_occurrence_individual'

  def self.endpoint(params)
    params.delete_if { |k, v| v.nil? || v.empty? }
    params = check_limit_offset(params)
    raise Exception.new('limit too large (max 1000)') unless (params[:limit] || 0) <= 1000
    cols = %w(scrubbed_species_binomial latitude longitude date_collected datasource dataset dataowner custodial_institution_codes collection_code view_full_occurrence_individual.datasource_id)
    select(cols.join(', '))
        .where(sprintf("scrubbed_species_binomial in ( '%s' ) AND higher_plant_group IS NOT NULL AND (is_geovalid = 1 OR is_geovalid IS NULL)", params[:species]))
        .order("scrubbed_species_binomial")
        .limit(params[:limit] || 10)
        .offset(params[:offset])
  end
end
# SELECT scrubbed_species_binomial,latitude,longitude,date_collected,datasource,dataset,dataowner,custodial_institution_codes,collection_code,view_full_occurrence_individual.datasource_id
# FROM view_full_occurrence_individual
# WHERE
#   scrubbed_species_binomial in ( 'Abies amabilis' ) AND
#   (is_cultivated = 0 OR is_cultivated IS NULL) AND
#   is_new_world = 1  AND
#   ( native_status IS NULL OR native_status NOT IN ( 'I', 'Ie' ) ) AND
#   higher_plant_group IS NOT NULL AND
#   (is_geovalid = 1 OR is_geovalid IS NULL)
# ORDER BY scrubbed_species_binomial

class OccurrenceGenus < ActiveRecord::Base
  self.table_name = 'view_full_occurrence_individual'

  def self.endpoint(params)
    params.delete_if { |k, v| v.nil? || v.empty? }
    params = check_limit_offset(params)
    raise Exception.new('limit too large (max 1000)') unless (params[:limit] || 0) <= 1000
    cols = %w(scrubbed_genus scrubbed_species_binomial latitude longitude date_collected datasource dataset dataowner custodial_institution_codes collection_code view_full_occurrence_individual.datasource_id)
    select(cols.join(', '))
        .where(sprintf("scrubbed_genus in ( '%s' ) AND higher_plant_group IS NOT NULL AND (is_geovalid = 1 OR is_geovalid IS NULL)", params[:genus]))
        .order("scrubbed_species_binomial")
        .limit(params[:limit] || 10)
        .offset(params[:offset])
  end
end

class OccurrenceFamily < ActiveRecord::Base
  self.table_name = 'view_full_occurrence_individual'

  def self.endpoint(params)
    params.delete_if { |k, v| v.nil? || v.empty? }
    params = check_limit_offset(params)
    raise Exception.new('limit too large (max 1000)') unless (params[:limit] || 0) <= 1000
    cols = %w(scrubbed_family scrubbed_species_binomial latitude longitude date_collected datasource dataset dataowner custodial_institution_codes collection_code view_full_occurrence_individual.datasource_id)
    select(cols.join(', '))
        .where(sprintf("scrubbed_family in ( '%s' ) AND higher_plant_group IS NOT NULL AND (is_geovalid = 1 OR is_geovalid IS NULL)", params[:family]))
        .order("scrubbed_species_binomial")
        .limit(params[:limit] || 10)
        .offset(params[:offset])
  end
end

## spatial
class OccurrenceSpatial < ActiveRecord::Base
  def self.endpoint(params)
    params.delete_if { |k, v| v.nil? || v.empty? }
    params = check_limit_offset(params)
    raise Exception.new('limit too large (max 1000)') unless (params[:limit] || 0) <= 1000
    cols = %w(scrubbed_species_binomial latitude longitude date_collected datasource dataset dataowner custodial_institution_codes collection_code a.datasource_id)
    select(cols.join(', '))
        .where("(SELECT * FROM view_full_occurrence_individual WHERE higher_plant_group IS NOT NULL AND is_geovalid =1 AND latitude BETWEEN :lat_min AND :lat_max AND longitude BETWEEN :lon_min AND :lon_max) a
            WHERE st_intersects(ST_GeographyFromText('SRID=4326; :wkt'), a.geom) AND (is_cultivated = 0 OR is_cultivated IS NULL) AND is_new_world = 1  AND ( native_status IS NULL OR native_status NOT IN ( 'I', 'Ie' ) )     AND higher_plant_group IS NOT NULL AND (is_geovalid = 1 OR is_geovalid IS NULL) ",
            {lat_min: params[:lat_min], lat_max: params[:lat_max], lon_min: params[:lon_min], lon_max: params[:lon_max], wkt: params[:wkt]})
        .order("scrubbed_species_binomial")
        .limit(params[:limit] || 10)
        .offset(params[:offset])
  end
end

## count
class OccurrenceCount < ActiveRecord::Base
  self.table_name = 'view_full_occurrence_individual'

  def self.endpoint(params)
    params.delete_if { |k, v| v.nil? || v.empty? }
    params = check_limit_offset(params)
    raise Exception.new('limit too large (max 1000)') unless (params[:limit] || 0) <= 1000
    sp = params[:species] || nil
    if sp.nil?
      select("scrubbed_species_binomial, count(*)")
        .distinct
        .where("is_geovalid = 1 AND latitude IS NOT NULL AND LONGITUDE IS NOT NULL")
        .group(:scrubbed_species_binomial)
        .limit(params[:limit] || 10)
        .offset(params[:offset])
    else
      select("scrubbed_species_binomial, count(*)")
        .where(sprintf("scrubbed_species_binomial in ( '%s' ) AND is_geovalid = 1", [sp].join("', '")))
        .group(:scrubbed_species_binomial)
        .limit(params[:limit] || 10)
        .offset(params[:offset])
    end
  end
end

# SELECT scrubbed_species_binomial,count(*)
#    FROM view_full_occurrence_individual
#    WHERE scrubbed_species_binomial in ( 'Abies lasiocarpa' ) AND is_geovalid = 1
#    GROUP BY scrubbed_species_binomial;

# "SELECT DISTINCT scrubbed_species_binomial,count(*)
#    FROM view_full_occurrence_individual
#    WHERE is_geovalid = 1 AND latitude IS NOT NULL AND LONGITUDE IS NOT NULL
#    GROUP BY scrubbed_species_binomial;"

## phylogeny model
class Phylogeny < ActiveRecord::Base
  self.table_name = 'phylogeny'

  def self.endpoint(params)
    params.delete_if { |k, v| v.nil? || v.empty? }
    params = check_limit_offset(params)
    raise Exception.new('limit too large (max 100)') unless (params[:limit] || 1) <= 100

    type = params[:type] || "conservative"
    if !["conservative", "complete"].include? type
      raise Exception.new("'type' must be either conservative or complete")
    end
    if type == "conservative"
      select('*')
        .where("phylogeny_version = 'BIEN_2016_conservative'")
    else
      nums = [*1..100].sample(limit).join("', '")
      select('*')
        .where(sprintf("phylogeny_version = 'BIEN_2016_complete' AND replicate in ( '%s' )", nums))
    end
  end
end

## meta models
### version
class MetaVersion < ActiveRecord::Base
  self.table_name = 'bien_metadata'
  def self.endpoint
    find_by_sql("SELECT db_version, db_release_date FROM bien_metadata a JOIN (SELECT MAX(bien_metadata_id) as max_id FROM bien_metadata) AS b ON a.bien_metadata_id=b.max_id;")
  end
end

### political names
class MetaPoliticalNames < ActiveRecord::Base
  self.table_name = 'county_parish'
  def self.endpoint(params)
    params.delete_if { |k, v| v.nil? || v.empty? }
    params = check_limit_offset(params)
    raise Exception.new('limit too large (max 1000)') unless (params[:limit] || 0) <= 1000
    select('country, country_id AS "country.code", state_province, state_province_ascii, state_province_code AS "state.code"')
    .limit(params[:limit] || 10)
    .offset(params[:offset])
  end
end


## range models
### list
class RangesList < ActiveRecord::Base
  self.table_name = 'ranges'

  def self.endpoint(params)
    params.delete_if { |k, v| v.nil? || v.empty? }
    params = check_limit_offset(params)
    raise Exception.new('limit too large (max 1000)') unless (params[:limit] || 0) <= 1000
    select('species, gid')
      .order("species")
      .limit(params[:limit] || 10)
      .offset(params[:offset])
  end
end

### species
class RangesSpecies < ActiveRecord::Base
  self.table_name = 'ranges'
  def self.endpoint(params)
    params.delete_if { |k, v| v.nil? || v.empty? }
    raise Exception.new('must pass "species" parameter') unless params[:species]
    sp = [params[:species]].map { |z| z.gsub(/\s/, '_') }
    mn = params[:match_names_only] || false
    x1 = %w(ST_AsText(geom) species gid)
    x2 = %w(species)
    cols = mn ? x2 : x1
    select(cols.join(', '))
      .where(sprintf("species in ( '%s' )", sp.join("', '")))
      .order("species")
  end
end

### genus
class RangesGenus < ActiveRecord::Base
  self.table_name = 'ranges'
  def self.endpoint(params)
    params.delete_if { |k, v| v.nil? || v.empty? }
    raise Exception.new('must pass "genus" parameter') unless params[:genus]
    ge = [params[:genus]].map { |z| sprintf('(%s_)', z) }
    mn = params[:match_names_only] || false
    x1 = %w(ST_AsText(geom) species gid)
    x2 = %w(species)
    cols = mn ? x2 : x1
    select(cols.join(', '))
      .where(sprintf("species ~ '%s'", ge.join('|')))
      .order("species")
  end
end

### spatial
# @param crop.ranges Should the ranges be cropped to the focal area? Default is FALSE.
# @param species.names.only Return species names rather than spatial data? Default is FALSE.
class RangesSpatial < ActiveRecord::Base
  self.table_name = 'ranges'
  def self.endpoint(params)
    params.delete_if { |k, v| v.nil? || v.empty? }
    raise Exception.new('must pass "wkt" parameter') unless params[:wkt]

    wkt = params[:wkt]
    if params[:species_names_only] || false
      if params[:crop_ranges] || false
        sel = sprintf("ST_AsText(ST_intersection(geom,ST_GeographyFromText('SRID=4326;%s'))),species,gid", wkt)
        select(sel)
          .where(sprintf("st_intersects(ST_GeographyFromText('SRID=4326;%s'),geom)", wkt))
      else
        sel = %w(ST_AsText(geom) species gid)
        select(sel.join(', '))
          .where(sprintf("st_intersects(ST_GeographyFromText('SRID=4326; %s'), geom)", wkt))
      end
    else 
      select(:species)
        .where(sprintf("st_intersects(ST_GeographyFromText('SRID=4326;%s'),geom)", wkt))
    end
  end
end


## stem models
### species
class StemSpecies < ActiveRecord::Base
  self.table_name = 'analytical_stem'

  def self.endpoint(params)
    params.delete_if { |k, v| v.nil? || v.empty? }
    params = check_limit_offset(params)
    raise Exception.new('limit too large (max 1000)') unless (params[:limit] || 0) <= 1000
    sel = %w(analytical_stem.analytical_stem_id analytical_stem.scrubbed_species_binomial analytical_stem.latitude
      analytical_stem.longitude analytical_stem.date_collected analytical_stem.relative_x_m
      analytical_stem.relative_y_m analytical_stem.taxonobservation_id
      analytical_stem.stem_code analytical_stem.stem_dbh_cm
      analytical_stem.stem_height_m plot_metadata.dataset plot_metadata.datasource
      plot_metadata.dataowner analytical_stem.custodial_institution_codes
      analytical_stem.collection_code analytical_stem.datasource_id)
    sp = params[:species]
    select(sel.join(', '))
        .from(sprintf(
          "(SELECT * FROM analytical_stem WHERE scrubbed_species_binomial in ( %s )) AS analytical_stem
          JOIN plot_metadata ON (analytical_stem.plot_metadata_id = plot_metadata.plot_metadata_id)
          JOIN view_full_occurrence_individual ON (analytical_stem.taxonobservation_id  = view_full_occurrence_individual.taxonobservation_id)",
          sp.split(',').map{ |z| "'#{z}'" }.join(', '))
        )
        .where(sprintf(
          "analytical_stem.scrubbed_species_binomial in ( %s )
          AND (analytical_stem.is_cultivated = 0 OR analytical_stem.is_cultivated IS NULL)
          AND analytical_stem.is_new_world = 1
          AND ( view_full_occurrence_individual.native_status IS NULL OR view_full_occurrence_individual.native_status NOT IN ( 'I', 'Ie' ) )
          AND analytical_stem.higher_plant_group IS NOT NULL
          AND (analytical_stem.is_geovalid = 1 OR analytical_stem.is_geovalid IS NULL)", sp.split(',').map{ |z| "'#{z}'" }.join(', ')
        ))
        .order('analytical_stem.scrubbed_species_binomial')
        .limit(params[:limit] || 10)
        .offset(params[:offset])
  end
end

### genus
class StemGenus < ActiveRecord::Base
  self.table_name = 'analytical_stem'

  def self.endpoint(params)
    params.delete_if { |k, v| v.nil? || v.empty? }
    params = check_limit_offset(params)
    raise Exception.new('limit too large (max 1000)') unless (params[:limit] || 0) <= 1000
    sel = %w(analytical_stem.scrubbed_genus analytical_stem.scrubbed_species_binomial analytical_stem.latitude
      analytical_stem.longitude analytical_stem.date_collected analytical_stem.relative_x_m
      analytical_stem.relative_y_m analytical_stem.taxonobservation_id
      analytical_stem.stem_code analytical_stem.stem_dbh_cm
      analytical_stem.stem_height_m plot_metadata.dataset plot_metadata.datasource
      plot_metadata.dataowner analytical_stem.custodial_institution_codes
      analytical_stem.collection_code analytical_stem.datasource_id)
    gen = params[:genus]
    select(sel.join(', '))
        .from(sprintf(
          "(SELECT * FROM analytical_stem WHERE scrubbed_genus in ( %s )) AS analytical_stem
          JOIN plot_metadata ON (analytical_stem.plot_metadata_id = plot_metadata.plot_metadata_id)
          JOIN view_full_occurrence_individual ON (analytical_stem.taxonobservation_id  = view_full_occurrence_individual.taxonobservation_id)",
          gen.split(',').map{ |z| "'#{z}'" }.join(', '))
        )
        .where(sprintf(
          "analytical_stem.scrubbed_genus in ( %s )
          AND (analytical_stem.is_cultivated = 0 OR analytical_stem.is_cultivated IS NULL)
          AND analytical_stem.is_new_world = 1
          AND ( view_full_occurrence_individual.native_status IS NULL OR view_full_occurrence_individual.native_status NOT IN ( 'I', 'Ie' ) )
          AND analytical_stem.higher_plant_group IS NOT NULL
          AND (analytical_stem.is_geovalid = 1 OR analytical_stem.is_geovalid IS NULL)", gen.split(',').map{ |z| "'#{z}'" }.join(', ')
        ))
        .order('analytical_stem.scrubbed_genus,analytical_stem.scrubbed_species_binomial')
        .limit(params[:limit] || 10)
        .offset(params[:offset])
  end
end


### family
class StemFamily < ActiveRecord::Base
  self.table_name = 'analytical_stem'

  def self.endpoint(params)
    params.delete_if { |k, v| v.nil? || v.empty? }
    params = check_limit_offset(params)
    raise Exception.new('limit too large (max 1000)') unless (params[:limit] || 0) <= 1000
    sel = %w(analytical_stem.scrubbed_family analytical_stem.scrubbed_genus analytical_stem.scrubbed_species_binomial 
      analytical_stem.latitude analytical_stem.longitude analytical_stem.date_collected analytical_stem.relative_x_m
      analytical_stem.relative_y_m analytical_stem.taxonobservation_id
      analytical_stem.stem_code analytical_stem.stem_dbh_cm
      analytical_stem.stem_height_m plot_metadata.dataset plot_metadata.datasource
      plot_metadata.dataowner analytical_stem.custodial_institution_codes
      analytical_stem.collection_code analytical_stem.datasource_id)
    fam = params[:family]
    select(sel.join(', '))
        .from(sprintf(
          "(SELECT * FROM analytical_stem WHERE scrubbed_family in ( %s )) AS analytical_stem
          JOIN plot_metadata ON (analytical_stem.plot_metadata_id = plot_metadata.plot_metadata_id)
          JOIN view_full_occurrence_individual ON (analytical_stem.taxonobservation_id  = view_full_occurrence_individual.taxonobservation_id)",
          fam.split(',').map{ |z| "'#{z}'" }.join(', '))
        )
        .where(sprintf(
          "analytical_stem.scrubbed_family in ( %s )
          AND (analytical_stem.is_cultivated = 0 OR analytical_stem.is_cultivated IS NULL)
          AND analytical_stem.is_new_world = 1
          AND ( view_full_occurrence_individual.native_status IS NULL OR view_full_occurrence_individual.native_status NOT IN ( 'I', 'Ie' ) )
          AND analytical_stem.higher_plant_group IS NOT NULL
          AND (analytical_stem.is_geovalid = 1 OR analytical_stem.is_geovalid IS NULL)", fam.split(',').map{ |z| "'#{z}'" }.join(', ')
        ))
        .order('analytical_stem.scrubbed_genus,analytical_stem.scrubbed_species_binomial')
        .limit(params[:limit] || 10)
        .offset(params[:offset])
  end
end


### datasource
class StemDataSource < ActiveRecord::Base
  self.table_name = 'analytical_stem'

  def self.endpoint(params)
    params.delete_if { |k, v| v.nil? || v.empty? }
    params = check_limit_offset(params)
    raise Exception.new('limit too large (max 1000)') unless (params[:limit] || 0) <= 1000
    sel = %w(analytical_stem.plot_name analytical_stem.subplot analytical_stem.elevation_m analytical_stem.plot_area_ha 
     analytical_stem.sampling_protocol analytical_stem.recorded_by analytical_stem.scrubbed_species_binomial 
     analytical_stem.latitude analytical_stem.longitude analytical_stem.date_collected analytical_stem.relative_x_m  
     analytical_stem.relative_y_m  analytical_stem.taxonobservation_id analytical_stem.stem_code  analytical_stem.stem_dbh_cm  
     analytical_stem.stem_height_m  plot_metadata.dataset plot_metadata.datasource plot_metadata.dataowner 
     analytical_stem.custodial_institution_codes  analytical_stem.collection_code analytical_stem.datasource_id)
    ds = params[:datasource]
    select(sel.join(', '))
        .from(sprintf(
          "(SELECT * FROM analytical_stem WHERE datasource in ( %s )) AS analytical_stem
          JOIN plot_metadata ON (analytical_stem.plot_metadata_id = plot_metadata.plot_metadata_id)
          JOIN view_full_occurrence_individual ON (analytical_stem.taxonobservation_id  = view_full_occurrence_individual.taxonobservation_id)",
          ds.split(',').map{ |z| "'#{z}'" }.join(', '))
        )
        .where(sprintf(
          "analytical_stem.datasource in ( %s )
          AND (analytical_stem.is_cultivated = 0 OR analytical_stem.is_cultivated IS NULL)
          AND analytical_stem.is_new_world = 1
          AND analytical_stem.higher_plant_group IS NOT NULL
          AND (analytical_stem.is_geovalid = 1 OR analytical_stem.is_geovalid IS NULL)", ds.split(',').map{ |z| "'#{z}'" }.join(', ')
        ))
        .order('analytical_stem.scrubbed_species_binomial')
        .limit(params[:limit] || 10)
        .offset(params[:offset])
  end
end

