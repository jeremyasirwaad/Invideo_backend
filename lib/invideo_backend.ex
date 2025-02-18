require Logger

defmodule InvideoBackend.Router do
  use Plug.Router
  use HTTPoison.Base

  plug(:match)
  plug(:dispatch)

  # Add CORS headers to the response
  defp add_cors_headers(conn) do
    conn
    |> Plug.Conn.put_resp_header("access-control-allow-origin", "*")
    |> Plug.Conn.put_resp_header("access-control-allow-methods", "GET, POST, OPTIONS")
    |> Plug.Conn.put_resp_header("access-control-allow-headers", "Content-Type, Authorization")
  end

  get "/" do
    Logger.error("Printing the error")
  end

  post "/process" do
    Logger.error("Got a request")
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    conn = add_cors_headers(conn)

    case Jason.decode(body) do
      {:ok, %{"input" => input}} ->
        response = call_anthropic_api(input)

        case response do
          {:ok, response_body} ->
            send_resp(conn, 200, response_body)

          {:error, reason} ->
            Logger.error(inspect(reason))
            send_resp(conn, 500, Jason.encode!(%{error: reason}))
        end

      {:error, _reason} ->
        send_resp(conn, 400, Jason.encode!(%{error: "Invalid JSON"}))
    end
  end

  # Handle OPTIONS requests for CORS preflight
  options _ do
    conn
    |> add_cors_headers()
    |> send_resp(204, "")
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end

  defp call_openai_api(input) do
    # Replace with your actual API key
    api_key = System.get_env("OPENAI_API_KEY")

    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]

    prompt =
      """
      You are a helpful assistant who generates shader code.
      You will be given the description of the shader to generate.

      # Shader Writing Rules
      1. Shader Structure
      The shader must be written in GLSL (OpenGL Shading Language).
      It should contain both a vertex shader and a fragment shader in a single string, separated by #fragment.
      The vertex shader must start with #vertex, and the fragment shader should follow after #fragment.

      Example format:
      ```glsl
      #vertex
      precision highp float;
      uniform vec2 u_resolution;
      uniform float u_time;
      varying vec2 v_uv;

      void main() {
      v_uv = position.xy * 0.5 + 0.5;
      gl_Position = vec4(position, 1.0);
      }

      #fragment
      precision highp float;
      uniform vec2 u_resolution;
      uniform float u_time;
      varying vec2 v_uv;

      void main() {
      gl_FragColor = vec4(v_uv, sin(u_time), 1.0);
      }```

      2. Uniforms Available
      Your shader will receive the following uniforms:

      uniform float u_time; – The elapsed time in seconds, updated every frame.
      uniform vec2 u_resolution; – The current viewport width and height in pixels.

      3. Vertex Shader Requirements
      Must define precision highp float;.
      Must accept attribute vec3 position;.
      Must output texture coordinates as a varying variable (e.g., varying vec2 v_uv;).
      gl_Position must be set correctly using position.
      Do not define the attribute position, as three.js already defines it.

      4. Fragment Shader Requirements
      Must define precision highp float;.
      Must declare varying vec2 v_uv; if texture coordinates are needed.
      Must output a color using gl_FragColor.
      Should use u_resolution to ensure correct scaling.
      Should avoid discarding pixels (discard;) unless absolutely necessary.
      Explicitly declare uniform float u_time; in the fragment shader

      5. Restrictions
      Do not use non-standard extensions (e.g., #extension GL_OES_standard_derivatives).
      Avoid defining your own attributes like attribute vec3 position; outside the standard ones.
      No dependencies on external textures (this renderer does not support texture sampling).
      Avoid infinite loops in the fragment shader (while(true) {}), as it may cause performance issues.

      Output Format: {“code”: <shader as string here>}
      """

    user_prompt = """
    # Description of the shader to generate:

    #{input}

    # Output json:
    """

    body =
      Jason.encode!(%{
        model: "gpt-4o",
        response_format: %{type: "json_object"},
        messages: [
          %{
            role: "system",
            content: prompt
          },
          %{role: "user", content: user_prompt}
        ]
      })

    url = "https://api.openai.com/v1/chat/completions"

    case HTTPoison.post(url, body, headers, timeout: 30_000, recv_timeout: 30_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        {:ok, response_body}

      {:ok, %HTTPoison.Response{status_code: status, body: response_body}} ->
        {:error, "OpenAI API returned status #{status}: #{response_body}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defp call_anthropic_api(input) do
    # Replace with your actual API key
    api_key = System.get_env("ANTHROPIC_API_KEY")

    headers = [
      {"Content-Type", "application/json"},
      {"x-api-key", api_key},
      {"anthropic-version", "2023-06-01"}
    ]

    prompt =
      """
      You are a helpful assistant who generates shader code.
      You will be given the description of the shader to generate.

      # Shader Writing Rules
      1. Shader Structure
      The shader must be written in GLSL (OpenGL Shading Language).
      It should contain both a vertex shader and a fragment shader in a single string, separated by #fragment.
      The vertex shader must start with #vertex, and the fragment shader should follow after #fragment.

      Example format:
      ```glsl
      #vertex
      precision highp float;
      uniform vec2 u_resolution;
      uniform float u_time;
      varying vec2 v_uv;

      void main() {
      v_uv = position.xy * 0.5 + 0.5;
      gl_Position = vec4(position, 1.0);
      }

      #fragment
      precision highp float;
      uniform vec2 u_resolution;
      uniform float u_time;
      varying vec2 v_uv;

      void main() {
      gl_FragColor = vec4(v_uv, sin(u_time), 1.0);
      }```

      2. Uniforms Available
      Your shader will receive the following uniforms:

      uniform float u_time; – The elapsed time in seconds, updated every frame.
      uniform vec2 u_resolution; – The current viewport width and height in pixels.

      3. Vertex Shader Requirements
      Must define precision highp float;.
      Must accept attribute vec3 position;.
      Must output texture coordinates as a varying variable (e.g., varying vec2 v_uv;).
      gl_Position must be set correctly using position.
      Do not define the attribute position, as three.js already defines it.

      4. Fragment Shader Requirements
      Must define precision highp float;.
      Must declare varying vec2 v_uv; if texture coordinates are needed.
      Must output a color using gl_FragColor.
      Should use u_resolution to ensure correct scaling.
      Should avoid discarding pixels (discard;) unless absolutely necessary.
      Explicitly declare uniform float u_time; in the fragment shader

      5. Restrictions
      Do not use non-standard extensions (e.g., #extension GL_OES_standard_derivatives).
      Avoid defining your own attributes like attribute vec3 position; outside the standard ones.
      No dependencies on external textures (this renderer does not support texture sampling).
      Avoid infinite loops in the fragment shader (while(true) {}), as it may cause performance issues.

      6. Output ONLY the shader code.

      # Output Code:
      ```glsl
      <shader as string here>
      ```
      """

    user_prompt = """
    # Description of the shader to generate:

    #{input}

    # Output Code:
    """

    body =
      Jason.encode!(%{
        model: "claude-3-5-sonnet-20241022",
        max_tokens: 8000,
        temperature: 0.3,
        system: prompt,
        messages: [
          %{role: "user", content: user_prompt}
        ]
      })

    url = "https://api.anthropic.com/v1/messages"

    case HTTPoison.post(url, body, headers, timeout: 30_000, recv_timeout: 30_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        {:ok, response_body}

      {:ok, %HTTPoison.Response{status_code: status, body: response_body}} ->
        {:error, "Anthropic API returned status #{status}: #{response_body}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end
end
