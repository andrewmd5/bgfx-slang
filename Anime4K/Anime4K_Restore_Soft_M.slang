// Anime4K Restore Soft M
// Based on Anime4K project by bloc97

import bgfx;

#ifdef BG_FP16
#pragma warning(disable: 3557)
#endif

Texture2D INPUT;

[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.POINT, AddressMode.CLAMP)]
SamplerState sam;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba16f")]
Texture2D tex1;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba16f")]
RWTexture2D<float4> tex1_UAV;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba16f")]
Texture2D tex2;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba16f")]
RWTexture2D<float4> tex2_UAV;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba16f")]
Texture2D tex3;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba16f")]
RWTexture2D<float4> tex3_UAV;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba16f")]
Texture2D tex4;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba16f")]
RWTexture2D<float4> tex4_UAV;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba16f")]
Texture2D tex5;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba16f")]
RWTexture2D<float4> tex5_UAV;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba16f")]
Texture2D tex6;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba16f")]
RWTexture2D<float4> tex6_UAV;

[bgfx::EFFECT("Anime4K Restore Soft M", 2)]
[bgfx::CATEGORY("Anime4K")]
[bgfx::DESCRIPTION("Soft detail restoration for anime content. Medium variant balances quality and performance.")]
[bgfx::FP16]
[bgfx::PASS(1, "Conv-4x3x3x3")]
[bgfx::PASS_IO("INPUT", "tex1_UAV")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1) + (tid.xy / 8) * 16;
    uint2 inputSize = GetInputSize();
    if (gxy.x >= inputSize.x || gxy.y >= inputSize.y)
    {
        return;
    }

    float2 inputPt = GetInputPt();

    half3 src[4][4];
    $for(ii in Range(0, 2))
    {
        $for(jj in Range(0, 2))
        {
            uint i = ii * 2;
            uint j = jj * 2;
            float2 tpos = (gxy + uint2(i, j)) * inputPt;
            const half4 sr = half4(INPUT.GatherRed(sam, tpos));
            const half4 sg = half4(INPUT.GatherGreen(sam, tpos));
            const half4 sb = half4(INPUT.GatherBlue(sam, tpos));

            src[i][j] = half3(sr.w, sg.w, sb.w);
            src[i][j + 1] = half3(sr.x, sg.x, sb.x);
            src[i + 1][j] = half3(sr.z, sg.z, sb.z);
            src[i + 1][j + 1] = half3(sr.y, sg.y, sb.y);
        }
    }

    $for(i in Range(1, 3))
    {
        $for(j in Range(1, 3))
        {
            uint2 destPos = gxy + uint2(i - 1, j - 1);

            bool shouldProcess = true;
            if (i != 1 || j != 1)
            {
                if (destPos.x >= inputSize.x || destPos.y >= inputSize.y)
                {
                    shouldProcess = false;
                }
            }

            if (shouldProcess)
            {
                half4 result = half4(-0.07697861h, 0.41154122h, 0.042374082h, -0.087270625h);
                result = MulAdd(src[i - 1][j - 1], half3x4(-0.073079124h, 0.11507942h, 0.028201895h, -0.021776304h, -0.25251916h, -0.08662003h, 0.38814726h, 0.4146095h, 0.06326891h, 0.01635252h, 0.06423356h, 0.13488062h), result);
                result = MulAdd(src[i - 1][j], half3x4(-0.059791833h, -0.03105604h, 0.041643705h, 0.35197195h, -0.17314838h, 0.067622855h, -0.032012507h, 0.09691628h, -0.11094062h, 0.007625051h, 0.094762206h, -0.05824145h), result);
                result = MulAdd(src[i - 1][j + 1], half3x4(-0.120281175h, 0.027440755h, -0.026316144h, -0.025291128h, -0.41698205h, -0.05966847h, -0.28400028h, -0.06946398h, -0.10906026h, -0.015854035h, -0.028724853h, -0.06626416h), result);
                result = MulAdd(src[i][j - 1], half3x4(0.068752654h, -0.12652585h, 0.38200122h, 0.17978846h, 0.2749825h, 0.015504972h, 0.21765926h, 0.2246602h, -0.062151223h, 0.07457783h, 0.13588274h, -0.037328478h), result);
                result = MulAdd(src[i][j], half3x4(0.3718559h, 0.025637252h, -0.4048626h, -0.41484925h, 0.24768798h, 0.09984098h, -0.5663632h, -0.6659978h, 0.212067h, -0.08328392h, -0.5277322h, -0.016879432h), result);
                result = MulAdd(src[i][j + 1], half3x4(-0.11072714h, -0.010321538h, 0.11265787h, 0.0055236337h, -0.13345073h, 0.004847663h, 0.3744461h, -0.4038564h, -0.09893075h, 0.031325124h, 0.2883957h, -0.04268903h), result);
                result = MulAdd(src[i + 1][j - 1], half3x4(0.10444391h, -0.60588187h, 0.02543334h, 0.10911738h, -0.10860678h, 0.15701362h, 0.29235297h, 0.045803998h, 0.076250754h, -0.10799697h, 0.08841044h, 0.08145623h), result);
                result = MulAdd(src[i + 1][j], half3x4(-0.04246739h, -0.1225759h, 0.11280305h, -0.12079673h, 0.5289142h, -0.011892906h, -0.0800465h, 0.05915611h, -0.126204h, 0.08239301h, -0.0092391195h, -0.07672885h), result);
                result = MulAdd(src[i + 1][j + 1], half3x4(-0.11922264h, 0.14036109h, -0.09491126h, 0.05112697h, -0.12543046h, -0.08662423h, -0.041537095h, 0.048038274h, 0.11672854h, -0.006516173h, -0.023524825h, 0.030505095h), result);

                tex1_UAV[destPos] = result;
            }
        }
    }
}

[bgfx::PASS(2, "Conv-4x3x3x8")]
[bgfx::PASS_IO("tex1", "tex2_UAV")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass2(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1) + (tid.xy / 8) * 16;
    uint2 inputSize = GetInputSize();
    if (gxy.x >= inputSize.x || gxy.y >= inputSize.y)
    {
        return;
    }

    float2 inputPt = GetInputPt();

    half4 src[4][4];
    $for(ii in Range(0, 2))
    {
        $for(jj in Range(0, 2))
        {
            uint i = ii * 2;
            uint j = jj * 2;
            float2 tpos = (gxy + uint2(i, j)) * inputPt;
            const half4 sr = half4(tex1.GatherRed(sam, tpos));
            const half4 sg = half4(tex1.GatherGreen(sam, tpos));
            const half4 sb = half4(tex1.GatherBlue(sam, tpos));
            const half4 sa = half4(tex1.GatherAlpha(sam, tpos));

            src[i][j] = half4(sr.w, sg.w, sb.w, sa.w);
            src[i][j + 1] = half4(sr.x, sg.x, sb.x, sa.x);
            src[i + 1][j] = half4(sr.z, sg.z, sb.z, sa.z);
            src[i + 1][j + 1] = half4(sr.y, sg.y, sb.y, sa.y);
        }
    }

    $for(i in Range(1, 3))
    {
        $for(j in Range(1, 3))
        {
            uint2 destPos = gxy + uint2(i - 1, j - 1);

            bool shouldProcess = true;
            if (i != 1 || j != 1)
            {
                if (destPos.x >= inputSize.x || destPos.y >= inputSize.y)
                {
                    shouldProcess = false;
                }
            }

            if (shouldProcess)
            {
                half4 result = half4(-0.08458621h, -0.023144595h, -0.057707336h, -0.081382714h);
                result = MulAdd(max(src[i - 1][j - 1], half4(0)), half4x4(-0.09419103h, -0.1178418h, 0.09523275h, 0.24648252h, 0.03595256h, -0.05417468h, -0.029167585h, -0.012279932h, 0.08852021h, -0.12534834h, 0.0604663h, 0.050634373h, -0.19536541h, 0.21548285h, 0.040379744h, -0.28046605h), result);
                result = MulAdd(max(src[i - 1][j], half4(0)), half4x4(-0.13783203h, 0.17191975h, 0.06956328h, 0.005270252h, -0.029844455h, -0.17657366h, 0.03439078h, 0.048861686h, 0.12017991h, -0.087307535h, 0.11815637h, 0.31309614h, 0.08440897h, 0.09969244h, -0.06220224h, 0.2633136h), result);
                result = MulAdd(max(src[i - 1][j + 1], half4(0)), half4x4(0.098606475h, -0.05856224h, -0.01163882h, -0.020945825h, -0.08988821h, 0.18520717h, 0.011407763h, 0.20973705h, 0.21017794h, 0.038311377h, -0.018910313h, 0.053878684h, -0.08751144h, -0.0081623215h, 0.29060364h, 0.14363094h), result);
                result = MulAdd(max(src[i][j - 1], half4(0)), half4x4(0.13354321h, -0.38046083h, 0.14157647h, 0.10190452h, -0.045502663h, 0.0053245644h, -0.10817685h, -0.048371315h, 0.16157807h, 0.2086147h, 0.07632662h, 0.24636099h, -0.0053555835h, -0.19587666h, -0.46687222h, 0.002362032h), result);
                result = MulAdd(max(src[i][j], half4(0)), half4x4(0.28275147h, -0.1468291h, 0.24075283h, -0.35119128h, 0.18727398h, 0.3833064h, 0.08667899h, 0.15021381h, -0.092296466h, -0.25686404h, -0.116076745h, 0.2231862h, -0.27637103h, 0.12317917h, -0.0341737h, -0.40077657h), result);
                result = MulAdd(max(src[i][j + 1], half4(0)), half4x4(-0.007041629h, 0.18089123h, -0.21195571h, -0.12346183h, -0.06088577h, -0.30784377h, 0.0048495876h, 0.06013008h, 0.07200418h, -0.0076884073h, 0.02632822h, -0.0011575016h, 0.21025613h, -0.2573419h, -0.06994815h, 0.32497165h), result);
                result = MulAdd(max(src[i + 1][j - 1], half4(0)), half4x4(0.0016823286h, -0.014366541h, -0.5049525h, 0.048534572h, -0.0057915323h, -0.0030526456h, -0.028976317h, -0.16376147h, -0.15560333h, -0.053708192h, -0.055678204h, -0.13087665h, 0.0048869387h, 0.027514834h, 0.017380254h, -0.06743363h), result);
                result = MulAdd(max(src[i + 1][j], half4(0)), half4x4(0.044514824h, -0.1754644h, -0.26664957h, 0.1486667h, 0.114894986h, 0.061640915h, -0.13305616h, 0.06450565h, 0.03552732h, 0.2835473h, 0.13800526h, 0.005875215h, 0.15751484h, 0.41759813h, -0.19406971h, 0.071032055h), result);
                result = MulAdd(max(src[i + 1][j + 1], half4(0)), half4x4(-0.18419577h, -0.05527526h, 0.017057603h, -0.1146602h, 0.15775396h, -0.01188916h, 0.09368113h, 0.05765405h, 0.064170234h, -0.017833546h, 0.12100514h, -0.06250493h, 0.2421206h, 0.15719843h, 0.23718071h, 0.023142194h), result);
                result = MulAdd(max(-src[i - 1][j - 1], half4(0)), half4x4(0.079226464h, 0.07877355h, -0.022315226h, -0.13507473h, 0.14683898h, 0.028739132h, -0.24479519h, -0.280197h, -0.13223173h, 0.21732429h, -0.1546993h, 0.045442928h, 0.163642h, -0.07062695h, 0.03805918h, 0.060860883h), result);
                result = MulAdd(max(-src[i - 1][j], half4(0)), half4x4(0.095216066h, -0.16650215h, -0.34863555h, -0.025274571h, 0.3064775h, -0.034196265h, -0.25773287h, 0.19570488h, -0.005434017h, 0.26308087h, 0.009404902h, -0.24736062h, 0.05558232h, -0.014217521h, 0.03667355h, -0.15134114h), result);
                result = MulAdd(max(-src[i - 1][j + 1], half4(0)), half4x4(-0.074846864h, 0.010901994h, 0.035149742h, 0.12106729h, -0.36042807h, -0.011231913h, 1.4317516h, 0.6400351h, 0.105860665h, -0.11587906h, -0.11065066h, 0.19126756h, 0.14132085h, 0.021570992h, -0.3618735h, -0.081163004h), result);
                result = MulAdd(max(-src[i][j - 1], half4(0)), half4x4(-0.06937371h, 0.3815214h, 0.026842717h, -0.04051589h, -0.09472515h, -0.027198657h, -0.16502109h, 0.114273794h, -0.15207845h, -0.15054241h, -0.25099036h, -0.10871029h, 0.14311226h, 0.07640166h, 0.47051275h, 0.0447809h), result);
                result = MulAdd(max(-src[i][j], half4(0)), half4x4(-0.25960425h, 0.11150338h, -0.042022616h, -0.006633396h, -0.29595324h, -0.0149574205h, 0.09806478h, 0.03635802h, 0.26789796h, 0.41416678h, 0.05145585h, 0.61168057h, 0.019582301h, -0.118703716h, 0.13974573h, 0.04498941h), result);
                result = MulAdd(max(-src[i][j + 1], half4(0)), half4x4(-0.04119621h, -0.15503803h, 0.33170196h, -0.1158483h, -0.06258357h, 0.2574262h, -0.07890287h, -0.6929032h, 0.004379942h, 0.097908296h, 0.009286624h, 0.27194506h, -0.2476702h, 0.13828708h, 0.05071857h, -0.43693772h), result);
                result = MulAdd(max(-src[i + 1][j - 1], half4(0)), half4x4(-0.010842703h, 0.13108006h, 0.30126816h, 0.20221521h, 0.018797455h, 0.0614624h, 0.11102966h, 0.019204421h, 0.09975456h, 0.04676902h, -0.044540443h, 0.118877h, -0.04871634h, -0.089208096h, 0.027455999h, 0.029557817h), result);
                result = MulAdd(max(-src[i + 1][j], half4(0)), half4x4(-0.10421777h, 0.3135469h, 0.14557797h, 0.0497297h, 0.0034963787h, -0.20342828h, 0.08332032h, -0.09004643h, 0.06574797h, -0.14168271h, -0.08754358h, 0.30385306h, -0.3374016h, -0.4360316h, 0.15854433h, -0.24081887h), result);
                result = MulAdd(max(-src[i + 1][j + 1], half4(0)), half4x4(0.1407836h, 0.09678823h, -0.02240152h, -0.013985894h, 0.012281648h, -0.24124922h, -0.46433777h, -0.25915003h, 0.042200714h, -0.21701157h, -0.016618999h, 0.13135725h, -0.34656256h, -0.034729004h, -0.29246503h, -0.13514486h), result);

                tex2_UAV[destPos] = result;
            }
        }
    }
}

[bgfx::PASS(3, "Conv-4x3x3x8")]
[bgfx::PASS_IO("tex2", "tex3_UAV")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass3(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1) + (tid.xy / 8) * 16;
    uint2 inputSize = GetInputSize();
    if (gxy.x >= inputSize.x || gxy.y >= inputSize.y)
    {
        return;
    }

    float2 inputPt = GetInputPt();

    half4 src[4][4];
    $for(ii in Range(0, 2))
    {
        $for(jj in Range(0, 2))
        {
            uint i = ii * 2;
            uint j = jj * 2;
            float2 tpos = (gxy + uint2(i, j)) * inputPt;
            const half4 sr = half4(tex2.GatherRed(sam, tpos));
            const half4 sg = half4(tex2.GatherGreen(sam, tpos));
            const half4 sb = half4(tex2.GatherBlue(sam, tpos));
            const half4 sa = half4(tex2.GatherAlpha(sam, tpos));

            src[i][j] = half4(sr.w, sg.w, sb.w, sa.w);
            src[i][j + 1] = half4(sr.x, sg.x, sb.x, sa.x);
            src[i + 1][j] = half4(sr.z, sg.z, sb.z, sa.z);
            src[i + 1][j + 1] = half4(sr.y, sg.y, sb.y, sa.y);
        }
    }

    $for(i in Range(1, 3))
    {
        $for(j in Range(1, 3))
        {
            uint2 destPos = gxy + uint2(i - 1, j - 1);

            bool shouldProcess = true;
            if (i != 1 || j != 1)
            {
                if (destPos.x >= inputSize.x || destPos.y >= inputSize.y)
                {
                    shouldProcess = false;
                }
            }

            if (shouldProcess)
            {
                half4 result = half4(0.0061747693h, -0.029145364h, -0.026801255h, 0.027419873h);
                result = MulAdd(max(src[i - 1][j - 1], half4(0)), half4x4(0.27743992h, 0.04277345h, 0.019331178h, -0.7335445h, 0.006292013h, 0.19800001h, -0.0025032016h, 0.16098699h, -0.03186617h, -0.060173523h, 0.08878855h, -0.10669283h, 0.130609h, -0.068515256h, -0.03571823h, -0.13751523h), result);
                result = MulAdd(max(src[i - 1][j], half4(0)), half4x4(-0.2430821h, -0.08233978h, 0.082374334h, 0.04843392h, -0.18989052h, -0.041925047h, 0.40021122h, -0.317836h, -0.13517766h, 0.032255337h, -0.0746507h, 0.22114721h, -0.045706213h, -0.12841983h, -0.27830583h, 0.05763077h), result);
                result = MulAdd(max(src[i - 1][j + 1], half4(0)), half4x4(-0.08436965h, -0.04967552h, -0.16798134h, -0.1539139h, -0.17429228h, -0.10166739h, 0.35864773h, 0.12873615h, -0.07667423h, 0.04985163h, 0.13391761h, -0.054322604h, 0.085659124h, -0.078792974h, 0.06481059h, 0.058667548h), result);
                result = MulAdd(max(src[i][j - 1], half4(0)), half4x4(-0.17568155h, 0.56705236h, 0.056562193h, -0.020951264h, 0.005879628h, -0.2502103h, -0.19619654h, 0.019490348h, -0.14527243h, 0.16983634h, 0.049245857h, 0.18316677h, 0.055053137h, 0.10699275h, 0.0016993808h, 0.20105995h), result);
                result = MulAdd(max(src[i][j], half4(0)), half4x4(0.36284775h, -0.05856962h, -0.42545465h, 0.31931567h, -0.15698905h, -0.28837132h, -0.028697362h, -0.024917847h, 0.04317283h, 0.024557106h, -0.052158598h, 0.38654143h, -0.1782944h, 0.43094924h, -0.11738149h, 0.21554618h), result);
                result = MulAdd(max(src[i][j + 1], half4(0)), half4x4(0.22645079h, -0.20319854h, 0.20733371h, -0.18697177h, -0.05167819h, -0.12845007h, 0.5543688h, 0.2453291h, 0.08027872h, -0.0628224h, -0.06593836h, -0.05795855h, -0.24527508h, 0.23632833h, -0.043366548h, 0.14135826h), result);
                result = MulAdd(max(src[i + 1][j - 1], half4(0)), half4x4(0.08384414h, 0.20807321h, 0.030559694h, -0.13640808h, -0.07641805h, -0.10919174h, -0.19799095h, -0.12955745h, 0.093737304h, -0.17856954h, 0.035103753h, -0.044699315h, -0.07255943h, -0.02331535h, 0.2059249h, 0.3058302h), result);
                result = MulAdd(max(src[i + 1][j], half4(0)), half4x4(0.022345139h, 0.16286038h, -0.27228013h, -0.41105714h, -0.0014384583h, 0.089546144h, -0.08296848h, -0.0050463285h, 0.07038578h, -0.030679917h, 0.031246305h, 0.36761853h, -0.34799108h, -0.0405689h, -0.19182852h, 0.015853593h), result);
                result = MulAdd(max(src[i + 1][j + 1], half4(0)), half4x4(0.1021783h, -0.11396049h, -0.08733628h, -0.017449526h, 0.042015605h, -0.14808236h, 0.10072531h, -0.07403295h, 0.15276712h, -0.07807765h, -0.10013386h, -0.26110634h, -0.04858846h, 0.066066965h, 0.13598624h, 0.21687816h), result);
                result = MulAdd(max(-src[i - 1][j - 1], half4(0)), half4x4(0.07041569h, -0.17775945h, 0.15697548h, -0.15425202h, -0.06569677h, -0.033233996h, 0.22596005h, -0.026170855h, -0.20729817h, 0.1316505h, -0.058410037h, 0.22166035h, 0.09107114h, -0.13078825h, -0.05639485h, -0.02716142h), result);
                result = MulAdd(max(-src[i - 1][j], half4(0)), half4x4(0.057966787h, -0.15311252h, 0.095924966h, -0.055951685h, 0.082777694h, -0.08471956h, -0.39918202h, 0.10599212h, 0.102710955h, 0.21808124h, 0.12083635h, -0.38835892h, 0.031709857h, 0.13955092h, 0.12647778h, 0.011549966h), result);
                result = MulAdd(max(-src[i - 1][j + 1], half4(0)), half4x4(0.09810508h, -0.119743295h, 0.06166254h, 0.13595435h, 0.036198203h, -0.028710455h, -0.40789905h, -0.034894038h, -0.12622337h, 0.14379597h, 0.039958883h, 0.19636424h, 0.047094557h, -0.07987105h, -0.04905092h, -0.07875785h), result);
                result = MulAdd(max(-src[i][j - 1], half4(0)), half4x4(0.34118712h, -0.2833933h, -0.045028314h, -0.40670308h, -0.01961924h, 0.37131935h, 0.29099533h, -0.19843055h, 0.18604252h, -0.0037280058h, 0.1091072h, -0.40579233h, 0.11422739h, -0.16490164h, -0.0022396361h, -0.21486944h), result);
                result = MulAdd(max(-src[i][j], half4(0)), half4x4(0.0010853866h, 0.2223109h, 0.2416471h, -0.33326814h, 0.2549397h, 0.6442047h, 0.18411863h, -0.19081281h, -0.43552014h, -0.1793875h, -0.58699155h, -0.01900168h, -0.26955804h, -0.071371995h, 0.07599079h, 0.27434483h), result);
                result = MulAdd(max(-src[i][j + 1], half4(0)), half4x4(-0.19644544h, 0.14383379h, -0.2599538h, 0.001666124h, -0.16369823h, 0.009537702h, -0.3690974h, -0.048157427h, -0.2040159h, 0.01522431h, -0.11007749h, -0.07012568h, 0.17536888h, -0.012183123h, -0.17366478h, -0.15090804h), result);
                result = MulAdd(max(-src[i + 1][j - 1], half4(0)), half4x4(0.0855136h, 0.06863859h, -0.17249937h, -0.12850079h, 0.15325847h, 0.22742507h, 0.22535504h, 0.24032994h, -0.109522276h, 0.24135293h, -0.17784368h, 0.08172238h, -0.16143093h, 0.1358853h, -0.09399085h, 0.012180792h), result);
                result = MulAdd(max(-src[i + 1][j], half4(0)), half4x4(-0.04346881h, 0.13367178h, 0.10387612h, 0.04705543h, -0.10315795h, 0.5816371h, -0.090529h, -0.017955385h, -0.09032907h, -0.52505773h, 0.10958755h, -0.26151448h, 0.17246644h, 0.011886279h, 0.3566306h, 0.32170597h), result);
                result = MulAdd(max(-src[i + 1][j + 1], half4(0)), half4x4(-0.27853554h, 0.1558035h, 0.070289604h, 0.17052644h, -0.31982365h, 0.29085326h, -0.09494764h, 0.2270542h, 0.10514691h, -0.24606484h, -0.02049181h, 0.126686h, 0.16719124h, 0.013080999h, -0.08577963h, -0.07057233h), result);

                tex3_UAV[destPos] = result;
            }
        }
    }
}

[bgfx::PASS(4, "Conv-4x3x3x8")]
[bgfx::PASS_IO("tex3", "tex4_UAV")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass4(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1) + (tid.xy / 8) * 16;
    uint2 inputSize = GetInputSize();
    if (gxy.x >= inputSize.x || gxy.y >= inputSize.y)
    {
        return;
    }

    float2 inputPt = GetInputPt();

    half4 src[4][4];
    $for(ii in Range(0, 2))
    {
        $for(jj in Range(0, 2))
        {
            uint i = ii * 2;
            uint j = jj * 2;
            float2 tpos = (gxy + uint2(i, j)) * inputPt;
            const half4 sr = half4(tex3.GatherRed(sam, tpos));
            const half4 sg = half4(tex3.GatherGreen(sam, tpos));
            const half4 sb = half4(tex3.GatherBlue(sam, tpos));
            const half4 sa = half4(tex3.GatherAlpha(sam, tpos));

            src[i][j] = half4(sr.w, sg.w, sb.w, sa.w);
            src[i][j + 1] = half4(sr.x, sg.x, sb.x, sa.x);
            src[i + 1][j] = half4(sr.z, sg.z, sb.z, sa.z);
            src[i + 1][j + 1] = half4(sr.y, sg.y, sb.y, sa.y);
        }
    }

    $for(i in Range(1, 3))
    {
        $for(j in Range(1, 3))
        {
            uint2 destPos = gxy + uint2(i - 1, j - 1);

            bool shouldProcess = true;
            if (i != 1 || j != 1)
            {
                if (destPos.x >= inputSize.x || destPos.y >= inputSize.y)
                {
                    shouldProcess = false;
                }
            }

            if (shouldProcess)
            {
                half4 result = half4(0.022887055h, 0.01521631h, 0.17967467h, -0.0131908795h);
                result = MulAdd(max(src[i - 1][j - 1], half4(0)), half4x4(0.07447851h, -0.07888509h, -0.28236163h, 0.2479792h, -0.065199964h, 0.24733023h, 0.099619575h, -0.26430824h, -0.03523585h, -0.03547245h, -0.10619345h, -0.25326422h, -0.116270036h, -0.065133184h, -0.30401528h, 0.01563764h), result);
                result = MulAdd(max(src[i - 1][j], half4(0)), half4x4(-0.19106275h, -0.26104823h, -0.14457102h, -0.17298317h, 0.24148639h, -0.10950928h, 0.062851585h, 0.042540826h, 0.13287601h, 0.06975747h, 0.15848075h, -0.3854902h, -0.13132331h, -0.16468687h, -0.029844414h, 0.27754608h), result);
                result = MulAdd(max(src[i - 1][j + 1], half4(0)), half4x4(0.015378025h, -0.14203559h, 0.08058816h, 0.32896644h, -0.074871175h, -0.26611313h, -0.18830848h, 0.091641426h, -0.16522385h, -0.23424402h, -0.12279703h, -0.13343342h, -0.2509982h, -0.0554576h, 0.07286022h, -0.028823337h), result);
                result = MulAdd(max(src[i][j - 1], half4(0)), half4x4(-0.13543738h, 0.049395677h, -0.015148539h, 0.13301241h, -0.12827122h, -0.012590744h, 0.012936948h, 0.008271658h, 0.12442749h, 0.3497426h, -0.16126058h, -0.2670464h, -0.010479037h, 0.07037434h, -0.15527055h, 0.13205245h), result);
                result = MulAdd(max(src[i][j], half4(0)), half4x4(-0.09535385h, -0.3931354h, 0.24716614h, -0.21284536h, 0.14652656h, 0.38149378h, -0.09607391h, 0.06350967h, 0.48615915h, 0.32634613h, 0.146291h, 0.2566475h, -0.40927815h, -0.05268087h, -0.04110691h, -0.0068722935h), result);
                result = MulAdd(max(src[i][j + 1], half4(0)), half4x4(0.089152284h, -0.01860622h, 0.016856732h, 0.31244752h, 0.022529159h, -0.0071319416h, -0.09786801h, -0.13005258h, 0.1524636h, 0.21627748h, -0.07395979h, -0.087633945h, -0.38435504h, -0.08842507h, -0.0058702417h, -0.32936293h), result);
                result = MulAdd(max(src[i + 1][j - 1], half4(0)), half4x4(0.0816838h, 0.0012210817h, 0.28217188h, 0.36141106h, 0.0014665248h, -0.0636269h, 0.042035818h, -0.056671552h, -0.032501306h, -0.22908778h, -0.2067977h, -0.004497514h, -0.23052917h, 0.26728114h, 0.15353456h, -0.17732324h), result);
                result = MulAdd(max(src[i + 1][j], half4(0)), half4x4(-0.17229734h, 0.0818218h, -0.10076918h, 0.030027041h, -0.14819005h, -0.085340135h, 0.050100215h, 0.05683199h, -0.12653661h, -0.036583595h, -0.32319903h, -0.15273796h, -0.15346588h, 0.20005536h, 0.23097478h, -0.19834782h), result);
                result = MulAdd(max(src[i + 1][j + 1], half4(0)), half4x4(0.055430107h, -0.2886931h, 0.361814h, 0.33160287h, -0.084407054h, 0.06254009h, -0.02332793h, -0.018134018h, -0.014879812h, 0.112346604h, -0.20686437h, -0.23408228h, -0.01091196h, -0.062669374h, 0.085567676h, 0.23738655h), result);
                result = MulAdd(max(-src[i - 1][j - 1], half4(0)), half4x4(0.080383554h, -0.1172084h, 0.19703126h, 0.27777427h, -0.07559937h, -0.25445858h, 0.3450109h, -0.071967736h, 0.2034805h, 0.33716002h, 0.15314537h, -0.22953224h, 0.113631405h, -0.0058444734h, 0.2890972h, 0.06557255h), result);
                result = MulAdd(max(-src[i - 1][j], half4(0)), half4x4(-0.17646056h, -0.025448758h, -0.14952567h, 0.017148364h, -0.15238142h, 0.1435677h, 0.20273875h, 0.22255951h, -0.011660059h, -0.003515217h, -0.17305166h, -0.13478355h, -0.06558679h, -0.032662887h, -0.20914736h, -0.5397283h), result);
                result = MulAdd(max(-src[i - 1][j + 1], half4(0)), half4x4(0.1679393h, -0.109410115h, -0.117427185h, 0.14982319h, -0.06457877h, -0.06607065h, 0.0018200208h, -0.0118605625h, 0.046539318h, -0.020642165h, -0.14413542h, -0.09530688h, 0.22196163h, -0.2187166h, -0.10759705h, 0.013234591h), result);
                result = MulAdd(max(-src[i][j - 1], half4(0)), half4x4(-0.13220267h, -0.12540027h, 0.26163217h, 0.12791659h, 0.16204996h, -0.4023048h, -0.13485721h, -0.10187536h, 0.059764992h, 0.048170995h, -0.25281772h, 0.2090587h, -0.06542371h, -0.10791867h, -0.21286209h, -0.309109h), result);
                result = MulAdd(max(-src[i][j], half4(0)), half4x4(0.16233061h, 0.120428756h, -0.11460241h, 0.24531102h, -0.2670459h, -0.24195078h, -0.20964348h, -0.12930301h, -0.2343609h, -0.22543164h, -0.28909695h, -0.33560297h, 0.6009884h, 0.39171818h, -0.1276308h, -0.020736236h), result);
                result = MulAdd(max(-src[i][j + 1], half4(0)), half4x4(0.40162864h, 0.045881115h, 0.032667033h, 0.31454235h, -0.17351128h, -0.009387306h, 0.17341217h, 0.30810982h, -0.025815086h, -0.10390133h, 0.012544771h, 0.036918722h, 0.34386298h, 0.23177734h, -0.046727546h, 0.20098232h), result);
                result = MulAdd(max(-src[i + 1][j - 1], half4(0)), half4x4(0.11541034h, -0.11647824h, -0.12874861h, 0.004921287h, -0.13921295h, -0.25733355h, -0.1112383h, -0.033295818h, 0.0035326157h, 0.3782048h, 0.055785846h, -0.1547331h, 0.17358719h, -0.2789715h, -0.13400431h, 0.1583795h), result);
                result = MulAdd(max(-src[i + 1][j], half4(0)), half4x4(0.4130191h, -0.33944547h, -0.064674884h, 0.39617148h, -0.11483455h, -0.022601767h, 0.1129301h, -0.09713594h, 0.14681247h, 0.34442267h, 0.08721343h, -0.08309499h, 0.088704996h, -0.20943391h, -0.2891408h, 0.1709401h), result);
                result = MulAdd(max(-src[i + 1][j + 1], half4(0)), half4x4(0.19503653h, 0.17490312h, -0.23491044h, -0.028934423h, 0.04479765h, -0.0334551h, 0.0602648h, 0.0019939998h, 0.23314747h, 0.21557438h, 0.07273092h, 0.15467109h, -0.11194509h, 0.0736583h, -0.17628083h, -0.3851578h), result);

                tex4_UAV[destPos] = result;
            }
        }
    }
}

[bgfx::PASS(5, "Conv-4x3x3x8")]
[bgfx::PASS_IO("tex4", "tex5_UAV")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass5(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1) + (tid.xy / 8) * 16;
    uint2 inputSize = GetInputSize();
    if (gxy.x >= inputSize.x || gxy.y >= inputSize.y)
    {
        return;
    }

    float2 inputPt = GetInputPt();

    half4 src[4][4];
    $for(ii in Range(0, 2))
    {
        $for(jj in Range(0, 2))
        {
            uint i = ii * 2;
            uint j = jj * 2;
            float2 tpos = (gxy + uint2(i, j)) * inputPt;
            const half4 sr = half4(tex4.GatherRed(sam, tpos));
            const half4 sg = half4(tex4.GatherGreen(sam, tpos));
            const half4 sb = half4(tex4.GatherBlue(sam, tpos));
            const half4 sa = half4(tex4.GatherAlpha(sam, tpos));

            src[i][j] = half4(sr.w, sg.w, sb.w, sa.w);
            src[i][j + 1] = half4(sr.x, sg.x, sb.x, sa.x);
            src[i + 1][j] = half4(sr.z, sg.z, sb.z, sa.z);
            src[i + 1][j + 1] = half4(sr.y, sg.y, sb.y, sa.y);
        }
    }

    $for(i in Range(1, 3))
    {
        $for(j in Range(1, 3))
        {
            uint2 destPos = gxy + uint2(i - 1, j - 1);

            bool shouldProcess = true;
            if (i != 1 || j != 1)
            {
                if (destPos.x >= inputSize.x || destPos.y >= inputSize.y)
                {
                    shouldProcess = false;
                }
            }

            if (shouldProcess)
            {
                half4 result = half4(0.049844168h, 0.02670437h, 0.050967637h, -0.10779561h);
                result = MulAdd(max(src[i - 1][j - 1], half4(0)), half4x4(-0.10233342h, -0.30233157h, 0.24238978h, -0.007108631h, 0.14248851h, 0.08486557h, 0.0028373515h, 0.122387215h, 0.10996857h, -0.17286511h, 0.19819227h, 0.07023527h, 0.07579955h, -0.16861476h, -0.210025h, 0.12760942h), result);
                result = MulAdd(max(src[i - 1][j], half4(0)), half4x4(0.091181986h, -0.41497424h, -0.27567792h, -0.09938067h, -0.12210428h, 0.20617811h, -0.017644284h, -0.22552875h, 0.049019493h, -0.18990634h, 0.11057753h, -0.043193225h, -0.15278774h, -0.18331046h, -0.1837594h, 0.029758787h), result);
                result = MulAdd(max(src[i - 1][j + 1], half4(0)), half4x4(-0.1757096h, -0.199691h, -0.034743477h, -0.15369363h, -0.1701244h, -0.0459655h, 0.10508695h, -0.09795581h, 0.13464944h, 0.37202564h, 0.14706515h, 0.23416734h, 0.08302458h, 0.20696343h, -0.13935481h, 0.03092827h), result);
                result = MulAdd(max(src[i][j - 1], half4(0)), half4x4(-0.49887478h, 0.24046332h, -0.029459715h, 0.17374687h, -0.15019977h, 0.31086043h, -0.28297687h, -0.22239804h, 0.12314376h, 0.11594825h, 0.17682782h, 0.09753434h, -0.26263535h, -0.12739435h, -0.57744014h, 0.087381124h), result);
                result = MulAdd(max(src[i][j], half4(0)), half4x4(0.08101439h, -0.16185337h, 0.112901986h, 0.24439482h, -0.44051018h, -0.70680356h, -0.23015513h, 0.63106006h, -0.08817581h, -0.057614524h, 0.15352182h, -0.049620207h, 0.17742544h, -0.49583626h, -0.3844133h, 0.18385352h), result);
                result = MulAdd(max(src[i][j + 1], half4(0)), half4x4(0.17149475h, 0.31255633h, 0.19286609h, 0.21052869h, -0.11856372h, -0.032373343h, 0.06503625h, -0.31664965h, 0.040755365h, -0.027614031h, -0.33330554h, 0.40148625h, 0.056921627h, -0.27068445h, 0.047014963h, 0.103712596h), result);
                result = MulAdd(max(src[i + 1][j - 1], half4(0)), half4x4(-0.09326643h, 0.13677256h, 0.06390537h, 0.08080093h, -0.10685094h, 0.124757454h, 0.14696303h, 0.10871933h, -0.10971212h, 0.01655797h, -0.11052674h, -0.17361104h, 0.015513338h, -0.1917502h, -0.26384255h, -0.022672707h), result);
                result = MulAdd(max(src[i + 1][j], half4(0)), half4x4(0.032367155h, -0.087523445h, -0.06951093h, -0.08128242h, 0.2627859h, 0.14933161h, 0.3114999h, -0.007791172h, -0.4146471h, -0.2530298h, -0.43175155h, -0.06878434h, 0.5724947h, 0.25498095h, 0.4838959h, 0.15076154h), result);
                result = MulAdd(max(src[i + 1][j + 1], half4(0)), half4x4(-0.13427481h, -0.10134261h, 0.087439895h, 0.015921364h, 0.15421022h, 0.20205952h, 0.22928835h, -0.07339068h, -0.33318612h, -0.17467582h, -0.04758165h, 0.11858059h, 0.17408857h, -0.099393494h, -0.06389948h, -0.06494366h), result);
                result = MulAdd(max(-src[i - 1][j - 1], half4(0)), half4x4(0.15349221h, 0.08508258h, -0.09294437h, -0.03204993h, -0.22561033h, -0.15088828h, -0.020105945h, 0.10041996h, -0.024723593h, 0.06610271h, -0.24423431h, -0.050512858h, -0.100530736h, 0.16394953h, 0.16365045h, -0.012055956h), result);
                result = MulAdd(max(-src[i - 1][j], half4(0)), half4x4(0.16342951h, 0.23113559h, 0.21289586h, 0.28391558h, 0.052211206h, -0.17983536h, -0.008415342h, 0.08977486h, -0.054481823h, 0.17506577h, -0.14162593h, -0.070448756h, 0.093877845h, 0.05161232h, -0.25006327h, 0.007014646h), result);
                result = MulAdd(max(-src[i - 1][j + 1], half4(0)), half4x4(0.104965575h, 0.20048036h, 0.024134496h, 0.5442797h, 0.19958296h, -0.05165447h, 0.076928124h, 0.030868227h, -0.0563495h, -0.19757621h, 0.10801544h, -0.24202053h, 0.0067657093h, -0.17784451h, -0.03134409h, -0.06741009h), result);
                result = MulAdd(max(-src[i][j - 1], half4(0)), half4x4(0.33347723h, -0.12338564h, 0.23495969h, -0.23091966h, 0.059872203h, 0.028045453h, -0.06781438h, 0.111325614h, -0.21861015h, -0.030451605h, -0.04267672h, -0.0039260075h, 0.0911101h, 0.054191053h, -0.08498816h, 0.04810343h), result);
                result = MulAdd(max(-src[i][j], half4(0)), half4x4(-0.05028896h, 0.21515386h, 0.16005337h, -0.32279232h, 0.19178568h, 0.779363h, -0.12682606h, -0.4378189h, 0.37980273h, 0.063021325h, 0.19370794h, -0.05618088h, -0.00088428083h, 0.29736623h, 0.24649377h, -0.0021625878h), result);
                result = MulAdd(max(-src[i][j + 1], half4(0)), half4x4(-0.45007992h, -0.16040307h, -0.1714593h, -0.16251564h, 0.070867635h, 0.21317895h, -0.070962h, 0.17147541h, -0.27786884h, -0.33259448h, -0.022767346h, -0.17967366h, 0.21208113h, 0.19740848h, 0.16877973h, 0.09630738h), result);
                result = MulAdd(max(-src[i + 1][j - 1], half4(0)), half4x4(0.09235827h, -0.35231477h, -0.093315996h, -0.035850406h, -0.08311695h, 0.054329164h, 0.17788444h, -0.020736141h, -0.03739786h, -0.1678283h, 0.12676615h, 0.17182353h, 0.17408027h, 0.07699043h, 0.095501214h, 0.0069830767h), result);
                result = MulAdd(max(-src[i + 1][j], half4(0)), half4x4(-0.16631392h, -0.16925642h, -0.17081848h, 0.017719474h, -0.20530944h, 0.19215193h, -0.039511178h, -0.08296625h, 0.2240653h, 0.100644305h, 0.2901835h, 0.32166973h, -0.10026419h, -0.14864013h, -0.19926691h, -0.11607018h), result);
                result = MulAdd(max(-src[i + 1][j + 1], half4(0)), half4x4(-0.13750182h, 0.07445518h, -0.033964884h, -0.085812084h, -0.03903257h, -0.054933593h, 0.06765632h, 0.064338475h, 0.27182797h, 0.07721309h, -0.0334218h, -0.19344835h, -0.14405386h, 0.046106674h, 0.16596143h, 0.0879945h), result);

                tex5_UAV[destPos] = result;
            }
        }
    }
}

[bgfx::PASS(6, "Conv-4x3x3x8")]
[bgfx::PASS_IO("tex5", "tex6_UAV")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass6(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1) + (tid.xy / 8) * 16;
    uint2 inputSize = GetInputSize();
    if (gxy.x >= inputSize.x || gxy.y >= inputSize.y)
    {
        return;
    }

    float2 inputPt = GetInputPt();

    half4 src[4][4];
    $for(ii in Range(0, 2))
    {
        $for(jj in Range(0, 2))
        {
            uint i = ii * 2;
            uint j = jj * 2;
            float2 tpos = (gxy + uint2(i, j)) * inputPt;
            const half4 sr = half4(tex5.GatherRed(sam, tpos));
            const half4 sg = half4(tex5.GatherGreen(sam, tpos));
            const half4 sb = half4(tex5.GatherBlue(sam, tpos));
            const half4 sa = half4(tex5.GatherAlpha(sam, tpos));

            src[i][j] = half4(sr.w, sg.w, sb.w, sa.w);
            src[i][j + 1] = half4(sr.x, sg.x, sb.x, sa.x);
            src[i + 1][j] = half4(sr.z, sg.z, sb.z, sa.z);
            src[i + 1][j + 1] = half4(sr.y, sg.y, sb.y, sa.y);
        }
    }

    $for(i in Range(1, 3))
    {
        $for(j in Range(1, 3))
        {
            uint2 destPos = gxy + uint2(i - 1, j - 1);

            bool shouldProcess = true;
            if (i != 1 || j != 1)
            {
                if (destPos.x >= inputSize.x || destPos.y >= inputSize.y)
                {
                    shouldProcess = false;
                }
            }

            if (shouldProcess)
            {
                half4 result = half4(-0.037546165h, -0.015675364h, 0.13989694h, 0.027605768h);
                result = MulAdd(max(src[i - 1][j - 1], half4(0)), half4x4(0.034357008h, 0.00082413113h, -0.13382089h, -0.05066409h, 0.26684088h, -0.31363875h, 0.073608615h, 0.20824149h, 0.21509308h, -0.07118628h, 0.11287014h, -0.09817389h, 0.16107765h, 0.17146803h, -0.13836654h, -0.05962866h), result);
                result = MulAdd(max(src[i - 1][j], half4(0)), half4x4(0.029981667h, 0.08738892h, 0.17735903h, 0.15817277h, 0.041752994h, -0.20031185h, 0.064203605h, 0.48786053h, -0.0033609737h, -0.42522693h, 0.058846988h, 0.22180536h, 0.17181319h, 0.13097888h, -0.059532285h, 0.062227458h), result);
                result = MulAdd(max(src[i - 1][j + 1], half4(0)), half4x4(0.13188283h, 0.07971828h, 0.28278515h, 0.038570832h, -0.12815465h, 0.29860008h, -0.2785862h, -0.07612298h, -0.14369671h, 0.12457525h, 0.11982623h, -0.018675303h, 0.14936846h, 0.1284789h, -0.0042489986h, 0.042810377h), result);
                result = MulAdd(max(src[i][j - 1], half4(0)), half4x4(0.2892425h, -0.20834558h, 0.07358541h, -0.11190968h, -0.16300741h, 0.15674856h, -0.04297203h, -0.29218298h, -0.036296643h, -0.052267153h, -0.22889943h, -0.21203549h, -0.03553075h, -0.20343691h, -0.07413655h, -0.092966415h), result);
                result = MulAdd(max(src[i][j], half4(0)), half4x4(0.2484468h, -0.23412868h, -0.070199326h, 0.2061922h, 0.5047224h, -0.48216155h, -0.5792768h, 0.610787h, 0.023935676h, -0.040435325h, -0.1238493h, -0.09576053h, -0.26183444h, 0.14510648h, 0.5365255h, 0.5499143h), result);
                result = MulAdd(max(src[i][j + 1], half4(0)), half4x4(-0.058255754h, 0.08133753h, -0.18663554h, 0.26190025h, 0.26006857h, -0.007619795h, 0.14585225h, 0.073580734h, -0.0396066h, 0.2821596h, 0.31778112h, -0.029853562h, -0.19703479h, 0.17809318h, 0.21089044h, -0.106730856h), result);
                result = MulAdd(max(src[i + 1][j - 1], half4(0)), half4x4(0.20549655h, -0.05962688h, 0.1432124h, 0.013446325h, -0.19064854h, 0.061387196h, 0.1792527h, 0.0010619498h, -0.1456842h, 0.18950678h, -0.13990986h, -0.37644413h, -0.083257h, -0.2937246h, 0.032096215h, 0.14719158h), result);
                result = MulAdd(max(src[i + 1][j], half4(0)), half4x4(-0.26601696h, 0.4242341h, -0.073702715h, -0.3221337h, 0.026037043h, -0.0117916465h, -0.024286825h, 0.23183465h, -0.030869482h, -0.045915652h, -0.040611852h, 0.11372697h, -0.25404635h, 0.21859063h, 0.13869432h, 0.19651218h), result);
                result = MulAdd(max(src[i + 1][j + 1], half4(0)), half4x4(-0.028276298h, -0.11217159h, 0.27144867h, -0.010531775h, 0.11032058h, -0.09957206h, 0.12570262h, 0.14724332h, 0.08758557h, -0.11042305h, 0.025948172h, -0.010910802h, -0.029466914h, -0.041135952h, -0.017091949h, 0.05501236h), result);
                result = MulAdd(max(-src[i - 1][j - 1], half4(0)), half4x4(-0.12688768h, -0.19051413h, 0.052141912h, -0.13618521h, -0.16320245h, -0.1601866h, 0.16207355h, -0.023218745h, 0.2103894h, -0.06212745h, -0.07042835h, 0.0996637h, -0.1763831h, 0.13890013h, -0.12125462h, -0.105104685h), result);
                result = MulAdd(max(-src[i - 1][j], half4(0)), half4x4(0.10485512h, -0.49283037h, -0.504295h, 0.009089699h, -0.17389494h, -0.12835866h, 0.14188384h, -0.22946316h, 0.006298799h, -0.0348454h, -0.0852419h, 0.17956656h, -0.08088888h, 0.35675287h, 0.16014415h, -0.055372503h), result);
                result = MulAdd(max(-src[i - 1][j + 1], half4(0)), half4x4(-0.17157564h, 0.1557075h, -0.17681694h, 0.14834762h, -0.13708206h, 0.101721555h, 0.17070566h, -0.22522852h, 0.08100986h, -0.23204406h, -0.38926315h, -0.13165781h, 0.1040296h, -0.045591615h, 0.15745829h, -0.10410621h), result);
                result = MulAdd(max(-src[i][j - 1], half4(0)), half4x4(-0.20517144h, 0.35896194h, -0.0010962893h, -0.18043008h, -0.016253468h, 0.035292216h, 0.06781499h, 0.015984116h, -0.20261237h, -0.28905126h, 0.007414641h, 0.008870292h, 0.52166605h, -0.0996688h, -0.23151648h, 0.2811893h), result);
                result = MulAdd(max(-src[i][j], half4(0)), half4x4(0.013482173h, -0.04891998h, -0.06094191h, -0.14416319h, -0.00087873987h, 0.11979091h, 0.06457245h, -0.2305623h, -0.1476981h, 0.2634587h, -0.058895197h, -0.07394766h, -0.27173743h, 0.7530214h, 0.037599873h, 0.22086331h), result);
                result = MulAdd(max(-src[i][j + 1], half4(0)), half4x4(-0.10357755h, 0.23899554h, 0.034912035h, -0.14336212h, -0.019786308h, -0.085470654h, -0.03096524h, 0.108783185h, 0.28971127h, 0.24527478h, -0.19110362h, -0.49510127h, -0.15574701h, 0.10968643h, -0.13727877h, 0.04502924h), result);
                result = MulAdd(max(-src[i + 1][j - 1], half4(0)), half4x4(-0.10808282h, -0.079148844h, -0.3244773h, -0.2210664h, -0.0062175165h, 0.1303082h, 0.012592612h, -0.38039228h, 0.26899642h, -0.16624425h, -0.04438198h, 0.42067865h, -0.13381268h, 0.03408099h, -0.2999706h, -0.3817641h), result);
                result = MulAdd(max(-src[i + 1][j], half4(0)), half4x4(0.030872926h, -0.26852018h, -0.14650428h, 0.16869825h, -0.19185568h, -0.06341456h, 0.12261606h, -0.26597574h, 0.44865233h, 0.21416639h, 0.40359476h, 0.12814924h, 0.2542566h, -0.23348318h, -0.43142912h, -0.35113996h), result);
                result = MulAdd(max(-src[i + 1][j + 1], half4(0)), half4x4(-0.03364283h, 0.11002299h, 0.3311268h, -0.14580412h, -0.10348537h, 0.13331696h, -0.0793144h, -0.04116661h, 0.040704627h, -0.14875266h, -0.09259674h, -0.062087066h, 0.063962296h, 0.18420577h, -0.085616685h, -0.16555141h), result);

                tex6_UAV[destPos] = result;
            }
        }
    }
}

[bgfx::PASS(7, "Conv-4x3x3x8, Conv-3x1x1x56")]
[bgfx::PASS_IO("INPUT, tex1, tex2, tex3, tex4, tex5, tex6", "OUTPUT")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass7(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1) + (tid.xy / 8) * 16;

    const uint2 outputSize = GetOutputSize();
    if (gxy.x >= outputSize.x || gxy.y >= outputSize.y)
    {
        return;
    }

    float2 inputPt = GetInputPt();
    float2 pos = (gxy + 0.5f) * inputPt;

    half4 a = half4(tex6.SampleLevel(sam, pos + float2(-inputPt.x, -inputPt.y), 0));
    half4 b = half4(tex6.SampleLevel(sam, pos + float2(-inputPt.x, 0), 0));
    half4 c = half4(tex6.SampleLevel(sam, pos + float2(-inputPt.x, inputPt.y), 0));
    half4 d = half4(tex6.SampleLevel(sam, pos + float2(0, -inputPt.y), 0));
    half4 e = half4(tex6.SampleLevel(sam, pos, 0));
    half4 f = half4(tex6.SampleLevel(sam, pos + float2(0, inputPt.y), 0));
    half4 g = half4(tex6.SampleLevel(sam, pos + float2(inputPt.x, -inputPt.y), 0));
    half4 h = half4(tex6.SampleLevel(sam, pos + float2(inputPt.x, 0), 0));
    half4 i = half4(tex6.SampleLevel(sam, pos + float2(inputPt.x, inputPt.y), 0));

    half4 src1 = half4(tex1.SampleLevel(sam, pos, 0));
    half4 src2 = half4(tex2.SampleLevel(sam, pos, 0));
    half4 src3 = half4(tex3.SampleLevel(sam, pos, 0));
    half4 src4 = half4(tex4.SampleLevel(sam, pos, 0));
    half4 src5 = half4(tex5.SampleLevel(sam, pos, 0));
    half4 src6 = half4(tex6.SampleLevel(sam, pos, 0));
    half3 origin = half3(INPUT.SampleLevel(sam, pos, 0).rgb);

    half4 src7 = half4(-0.20554838h, -0.10647836h, -0.02824578h, 0.08658529h);
    src7 = MulAdd(max(a, half4(0)), half4x4(-0.35835463h, 0.038305778h, -0.10198824h, -0.021951782h, 0.02142098h, -0.072417736h, -0.2577152h, 0.054713376h, 0.075116105h, -0.21191697h, -0.1213158h, -0.105036296h, 0.12030758h, -0.17591658h, 0.1726511h, 0.17754573h), src7);
    src7 = MulAdd(max(b, half4(0)), half4x4(0.32325825h, 0.19869742h, 0.333873h, 0.39670366h, 0.20716824h, 0.09557955h, 0.120742686h, -0.2271023h, 0.37509173h, -0.031341635h, 0.10247365h, 0.031520665h, -0.092765376h, -0.13535516h, 0.8333728h, 0.05886494h), src7);
    src7 = MulAdd(max(c, half4(0)), half4x4(-0.17573749h, 0.16768494h, 0.021141645h, 0.19668253h, 0.21080776h, 0.31503728h, -0.26834h, 0.19103156h, 0.21946241h, 0.14559007h, -0.09761235h, -0.23565038h, -0.49393657h, -0.5332298h, 0.09806347h, 0.054431103h), src7);
    src7 = MulAdd(max(d, half4(0)), half4x4(-0.042109374h, -0.05564321h, 0.27586877h, 0.010382545h, 0.007322007h, 0.13193823h, -0.18262729h, 0.06399193h, 0.14174329h, 0.3898842h, -0.10398105h, 0.01846146h, -0.24542394h, -0.13020967h, -0.16491668h, -0.03544872h), src7);
    src7 = MulAdd(max(e, half4(0)), half4x4(-0.15291597h, 0.1566557h, 0.14745249h, -0.23258151h, 0.17843612h, 0.15885495h, -0.691466h, -0.41177312h, 0.40330106h, -0.07991953h, 0.2832403h, 0.10656986h, -0.19571523h, 0.3670614h, -0.62296015h, -0.5666968h), src7);
    src7 = MulAdd(max(f, half4(0)), half4x4(-0.17513512h, 0.011393021h, -0.44352317h, -0.059153114h, -0.2227142h, -0.033094753h, 0.09624524h, 0.051315393h, 0.2632246h, 0.09945105h, 0.042561427h, -0.1234722h, 0.23755905h, -0.506999h, 0.114180565h, 0.27887583h), src7);
    src7 = MulAdd(max(g, half4(0)), half4x4(-0.459564h, -0.120326266h, 0.17507194h, 0.06701153h, -0.14124362h, -0.36653697h, -0.2856802h, -0.22955593h, -0.08515889h, 0.18788262h, 0.23427077h, 0.021544341h, 0.31996533h, -0.2668834h, 0.08469808h, -0.01347926h), src7);
    src7 = MulAdd(max(h, half4(0)), half4x4(-0.14092083h, -0.31244513h, -0.044023518h, 0.013948701h, 0.33119613h, -0.011959397h, -0.1494438h, -0.111066826h, -0.11994278h, 0.116068155h, -0.13032633h, -0.037004936h, 0.13851176h, -0.006655432h, -0.39841232h, -0.079951204h), src7);
    src7 = MulAdd(max(i, half4(0)), half4x4(-0.08959123h, 0.18297827h, -0.0763483h, 0.11364159h, -0.04361797h, -0.029816678h, -0.19314721h, -0.03484794h, 0.044681285h, 0.04669291h, -0.30017474h, -0.07453036h, 0.090825416h, -0.27414632h, 0.36355078h, 0.15742934h), src7);
    src7 = MulAdd(max(-a, half4(0)), half4x4(0.18470702h, 0.113800436h, -0.18546791h, 0.044184085h, 0.12490399h, 0.1826781h, -0.01313173h, -0.19048993h, -0.026458051h, -0.1693334h, 0.21958382h, 0.030458853h, -0.059242606h, 0.039351143h, -0.061676584h, -0.06904634h), src7);
    src7 = MulAdd(max(-b, half4(0)), half4x4(-0.114877924h, -0.03781683h, -0.19207929h, 0.007679428h, 0.2409049h, 0.2965285h, -0.38395065h, 0.11604976h, -0.22588749h, 0.48505852h, 0.09866521h, -0.2585994h, -0.011380872h, -0.018334057h, -0.047188547h, 0.3038583h), src7);
    src7 = MulAdd(max(-c, half4(0)), half4x4(-0.2783936h, -0.17609318h, 0.4904369h, -0.31848624h, 0.39725313h, 0.082951784h, -0.15595853h, -0.007526218h, 0.2355193h, -0.30003366h, -0.27686292h, 0.120900005h, -0.1223885h, 0.40760317h, 0.0013726618h, -0.24877374h), src7);
    src7 = MulAdd(max(-d, half4(0)), half4x4(0.1580051h, -0.044973504h, 0.00053594523h, -0.057797022h, 0.18895927h, 0.23527777h, -0.18095906h, -0.076961614h, 0.2544444h, -0.05932328h, 0.13717431h, -0.024487074h, 0.33157274h, -0.09072586h, -0.004386734h, -0.05180953h), src7);
    src7 = MulAdd(max(-e, half4(0)), half4x4(-0.21685815h, 0.061656334h, -0.066127226h, 0.24831405h, 0.26001146h, 0.046466008h, -0.047196623h, 0.13538954h, -0.06449239h, 0.45951647h, -0.13132116h, -0.7079741h, -0.06683439h, -0.47628635h, 0.42461708h, 0.6475073h), src7);
    src7 = MulAdd(max(-f, half4(0)), half4x4(0.2590011h, -0.26020283h, 0.0005333198h, 0.01555692h, 0.37920526h, 0.29205114h, -0.20281325h, -0.1455974h, 0.056119893h, 0.022032745h, -0.30095813h, 0.48154855h, -0.35761952h, 0.07582935h, 0.12462687h, 0.068093665h), src7);
    src7 = MulAdd(max(-g, half4(0)), half4x4(0.20434918h, 0.26690874h, 0.028224666h, 0.042565826h, 0.037406113h, 0.5059272h, -0.0047208676h, 0.0019095197h, 0.16626422h, -0.23407575h, -0.072687164h, 0.00063299487h, -0.10172441h, -0.11645544h, 0.008715937h, -0.012423992h), src7);
    src7 = MulAdd(max(-h, half4(0)), half4x4(0.08269191h, 0.116322584h, -0.08155921h, -0.04790326h, 0.09546776h, 0.3632936h, -0.08139031h, -0.10399187h, 0.06618616h, -0.26862565h, 0.25058737h, 0.0410593h, -0.07191658h, -0.20559746h, 0.21857823h, 0.12776822h), src7);
    src7 = MulAdd(max(-i, half4(0)), half4x4(0.54989135h, 0.38051483h, 0.015739547h, -0.0068143173h, 0.26107135h, 0.2585036h, -0.12345306h, -0.13934542h, -0.19018838h, 0.2730626h, 0.42644337h, 0.16693048h, -0.15189888h, 0.023638237h, 0.11272267h, 0.039560657h), src7);

    half3 result = half3(-0.0039074384h, -0.0085585555h, -0.0132283475h);
    result = MulAdd(max(src1, half4(0)), half4x3(-0.030150581h, -0.002168429h, 0.014918388h, 0.020940892h, 0.04591048h, 0.049137186h, 0.111167125h, 0.05311203h, 0.0625381h, 0.020043287h, 0.04785493h, 0.040921766h), result);
    result = MulAdd(max(-src1, half4(0)), half4x3(0.04158565h, -0.008488135h, 0.0020472286h, 0.049123142h, -0.055042226h, -0.06489915h, 0.09238876h, 0.10387972h, 0.09576964h, -0.054776173h, -0.098954335h, -0.09018853h), result);
    result = MulAdd(max(src2, half4(0)), half4x3(0.2081418h, 0.08273068h, 0.040325668h, -0.09937802h, -0.13162258h, -0.13989717h, -0.13983749h, 0.01309777h, 0.0023888077h, -0.18937743h, -0.07021057h, -0.047152344h), result);
    result = MulAdd(max(-src2, half4(0)), half4x3(-0.09646629h, 0.080605574h, 0.10463501h, 0.22579835h, 0.24077554h, 0.22600271h, 0.049726978h, 0.015292378h, -0.0047161994h, 0.16281025h, 0.048491795h, 0.038338162h), result);
    result = MulAdd(max(src3, half4(0)), half4x3(-0.09772107h, -0.043998875h, -0.054745924h, -0.1257736h, -0.13175423h, -0.10889618h, -0.015900036h, 0.07074481h, 0.08210496h, -0.11321135h, -0.12526917h, -0.105605066h), result);
    result = MulAdd(max(-src3, half4(0)), half4x3(0.14187162h, 0.14032297h, 0.13016908h, 0.018954534h, 0.016011704h, 0.010169183h, 0.04762765h, -0.044460997h, -0.06499567h, 0.11133751h, 0.09464176h, 0.08865274h), result);
    result = MulAdd(max(src4, half4(0)), half4x3(-0.16567162h, -0.1744712h, -0.1637222h, -0.02412003h, 0.0074480795h, 0.007903436h, -0.06161098h, -0.046788957h, -0.03971239h, 0.030736001h, 0.036460854h, 0.03660504h), result);
    result = MulAdd(max(-src4, half4(0)), half4x3(0.084027h, 0.10024112h, 0.08152756h, 0.005087354h, -0.026047802h, -0.027264625h, 0.10519243h, 0.08977278h, 0.077558964h, -0.052826345h, -0.06602686h, -0.055083472h), result);
    result = MulAdd(max(src5, half4(0)), half4x3(0.007862721h, 0.009936555h, 0.012004831h, -0.042322706h, -0.061728776h, -0.05359773h, 0.030532641h, 0.045623366h, 0.04214089h, 0.030569768h, 0.011892851h, 0.0074041556h), result);
    result = MulAdd(max(-src5, half4(0)), half4x3(0.03948997h, 0.043119986h, 0.039943404h, 0.0526772h, 0.06820589h, 0.058139592h, -0.062081397h, -0.06755701h, -0.054816127h, -0.004076369h, 0.0061744447h, 0.016273081h), result);
    result = MulAdd(max(src6, half4(0)), half4x3(0.0071622543h, 0.004829105h, -0.002032197h, -0.048541367h, -0.059043564h, -0.05662218h, 0.0015553127h, 0.009178359h, 0.009577062h, 0.114169896h, 0.1349016h, 0.11432262h), result);
    result = MulAdd(max(-src6, half4(0)), half4x3(0.019324556h, 0.028323999h, 0.027396113h, 0.016746879h, 0.01608199h, 0.026891617h, 0.12068619h, 0.13617857h, 0.113496214h, -0.013930715h, -0.014250072h, -0.00824306h), result);
    result = MulAdd(max(src7, half4(0)), half4x3(-0.0024534757h, -0.0064973077h, -0.007905654h, -0.019158727h, -0.024820521h, -0.020509848h, -0.09608131h, -0.11177871h, -0.10503465h, -0.011210447h, -0.010875943h, -0.015295865h), result);
    result = MulAdd(max(-src7, half4(0)), half4x3(0.09681486h, 0.113604136h, 0.10416855h, -0.08199983h, -0.09013433h, -0.08562243h, 0.041304465h, 0.048315883h, 0.042945288h, -0.09863276h, -0.117853515h, -0.09870226h), result);

    OUTPUT[gxy] = float4(result + origin, 1);
}
