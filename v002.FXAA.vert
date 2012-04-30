
void main()
{
    gl_Position = ftransform();

    // transform texcoords
	gl_TexCoord[0] = gl_TextureMatrix[0] * gl_MultiTexCoord0;
}