require "sprockets_test"

class ConcatenatedAssetTest < Sprockets::TestCase
  def setup
    @env = Sprockets::Environment.new
    @env.paths << fixture_path('asset')
  end

  test "requiring the same file multiple times has no effect" do
    assert_equal source_file("project.js").source, asset("multiple.js").to_s
  end

  test "requiring a file of a different format raises an exception" do
    assert_raise Sprockets::ContentTypeMismatch do
      asset("mismatch.js")
    end
  end

  test "dependencies appear in the source before files that required them" do
    assert_match(/Project.+Users.+focus/m, asset("application.js").to_s)
  end

  test "processing a source file with no engine extensions" do
    assert_equal source_file("users.js").source, asset("noengine.js").to_s
  end

  test "processing a source file with one engine extension" do
    assert_equal source_file("users.js").source, asset("oneengine.js").to_s
  end

  test "processing a source file with multiple engine extensions" do
    assert_equal source_file("users.js").source,
      asset("multipleengine.js").to_s
  end

  test "processing a source file with unknown extensions" do
    assert_equal source_file("users.js").source + "jQuery\n",
      asset("unknownexts.min.js").to_s
  end

  test "processing a source file in compat mode" do
    assert_equal source_file("project.js").source + source_file("users.js").source,
      asset("compat.js").to_s
  end

  test "included dependencies are inserted after the header of the dependent file" do
    assert_equal "# My Application\n" + source_file("project.js").source + "\nhello()\n",
      asset("included_header.js").to_s
  end

  test "requiring a file with a relative path" do
    assert_equal source_file("project.js").source,
      asset("relative/require.js").to_s
  end

  test "including a file with a relative path" do
    assert_equal "// Included relatively\n" + source_file("project.js").source + "\nhello()\n", asset("relative/include.js").to_s
  end

  test "can't require files outside the load path" do
    assert_raise Sprockets::FileNotFound do
      asset("relative/require_outside_path.js")
    end
  end

  test "require_tree requires all descendant files in alphabetical order" do
    assert_equal(
      asset("tree/all_with_require.js").to_s,
      asset("tree/all_with_require_tree.js").to_s
    )
  end

  test "require_tree without an argument defaults to the current directory" do
    assert_equal(
      "a()\n\nb()\n\n",
      asset("tree/without_argument/require_tree_without_argument.js").to_s
    )
  end

  test "require_tree with a logical path argument raises an exception" do
    assert_raise(Sprockets::ArgumentError) do
      asset("tree/with_logical_path/require_tree_with_logical_path.js").to_s
    end
  end

  test "__FILE__ is properly set in templates" do
    assert_equal %(var filename = "#{resolve("filename.js").path}";\n),
      asset("filename.js").to_s
  end

  test "asset mtime is the latest mtime of all processed sources" do
    mtime = Time.now
    path  = source_file("project.js").path
    File.utime(mtime, mtime, path)
    assert_equal File.mtime(path), asset("application.js").mtime
  end

  test "asset inherits the format extension and content type of the original file" do
    asset = asset("project.js")
    assert_equal ".js", asset.format_extension
    assert_equal "application/javascript", asset.content_type
  end

  if Tilt::CoffeeScriptTemplate.respond_to?(:default_mime_type)
    test "asset falls back to engines default mime type" do
      asset = asset("default_mime_type.js")
      assert_equal ".js", asset.format_extension
      assert_equal "application/javascript", asset.content_type
    end
  end

  test "asset is a rack response body" do
    body = ""
    asset("project.js").each { |part| body += part }
    assert_equal asset("project.js").to_s, body
  end

  test "asset length is source length" do
    assert_equal 46, asset("project.js").length
  end

  test "asset length is source length with unicode characters" do
    assert_equal 4, asset("unicode.js").length
  end

  test "asset digest" do
    assert_equal "729a810640240adfd653c3d958890cfc4ec0ea84", asset("project.js").digest
  end

  test "asset is stale when one of its source files is modified" do
    asset = asset("application.js")
    assert !asset.stale?

    mtime = Time.now + 1
    File.utime(mtime, mtime, source_file("project.js").path)

    assert asset.stale?
  end

  test "legacy constants.yml" do
    assert_equal "var Prototype = { version: '2.0' };\n",
      asset("constants.js").to_s
  end

  test "serialize to json" do
    json = asset("application.js").to_json
    assert_match "Sprockets::ConcatenatedAsset", json
    assert_match "application/javascript", json
    assert_match ".js", json
    assert_match "deacf69d66fa11710f3197cd175c744abf5bb8fd", json
  end

  test "unserialize from json" do
    filename = File.join(fixture_path('asset'), "application.js")
    asset = JSON.parse({
      'json_class'       => "Sprockets::ConcatenatedAsset",
      'content_type'     => "application/javascript",
      'format_extension' => ".js",
      'source_paths'     => [filename],
      'source'           => [File.read(filename)],
      'mtime'            => File.mtime(filename),
      'length'           => File.read(filename).length,
      'digest'           => "deacf69d66fa11710f3197cd175c744abf5bb8fd"
    }.to_json)

    assert_kind_of Sprockets::ConcatenatedAsset, asset
    assert_equal "application/javascript", asset.content_type
    assert_equal ".js", asset.format_extension
    assert_equal Set.new([filename]), asset.send(:source_paths)
    assert_equal 109, asset.to_s.length
    assert_equal File.mtime(filename), asset.mtime
    assert_equal 109, asset.length
    assert_equal "deacf69d66fa11710f3197cd175c744abf5bb8fd", asset.digest
  end

  test "reciprocal serialization functions" do
    # assert_equal @asset, JSON.parse(@asset.to_json)
  end

  def asset(logical_path)
    Sprockets::ConcatenatedAsset.new(@env, resolve(logical_path))
  end

  def resolve(logical_path)
    @env.resolve(logical_path)
  end

  def source_file(logical_path)
    Sprockets::SourceFile.new(resolve(logical_path))
  end
end
