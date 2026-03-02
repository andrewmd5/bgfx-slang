// Anime4K Upscale Denoise CNN x2 (Small)
// Based on Anime4K project by bloc97

import bgfx;

#ifdef BG_FP16
#pragma warning(disable: 3557)
#endif

Texture2D INPUT;

[bgfx::SIZE("INPUT_WIDTH * 2", "INPUT_HEIGHT * 2")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.POINT, AddressMode.CLAMP)]
SamplerState sam;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState sam1;

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

[bgfx::EFFECT("Anime4K Upscale Denoise S", 2)]
[bgfx::CATEGORY("Anime4K")]
[bgfx::DESCRIPTION("2x upscaler with denoising for anime content. Small variant offers fastest performance with basic quality.")]
[bgfx::FP16]
[bgfx::PASS(1, "Feature Extraction Conv-4x3x3x3")]
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
                half4 result = half4(-0.004601904h, -0.0030944077h, 0.14569537h, -0.016794242h);
                result = MulAdd(src[i - 1][j - 1], half3x4(6.5515305e-05h, 0.09565814h, -0.0022499533h, 0.14627136h, -0.0065872427h, 0.1441769h, 0.17772098h, 0.16298898h, 0.03727593h, 0.02010636h, 0.013131043h, 0.07891907h), result);
                result = MulAdd(src[i - 1][j], half3x4(0.029612074h, -0.01204274h, 0.07698074h, 0.3855172h, 0.0045466167h, -0.0859741h, 0.26930287h, 0.67549795h, -0.036623597h, 0.051749162h, -0.04714053h, 0.16092339h), result);
                result = MulAdd(src[i - 1][j + 1], half3x4(-0.030328937h, -0.15884648h, 0.0082092965h, -0.05052196h, 0.041409027h, -0.23017453h, 0.31568366h, 0.05136558h, -0.0106390705h, -0.12503141h, -0.07030922h, -0.08512375h), result);
                result = MulAdd(src[i][j - 1], half3x4(0.059616547h, -0.12322959h, 0.058520414h, -0.039292034h, 0.08059592h, -0.22441447h, 0.15380386h, -0.17675085h, -0.009270574h, 0.034731936h, -0.048767723h, 0.025933916h), result);
                result = MulAdd(src[i][j], half3x4(-0.4495482h, 0.37551787h, -0.4227873h, -0.4890034h, -0.9007091h, 0.7524192h, -1.271679h, -0.68366605h, -0.07302573h, 0.09378561h, 0.010367829h, -0.24593607h), result);
                result = MulAdd(src[i][j + 1], half3x4(0.12684742h, -0.11042779h, 0.01793761h, 0.06982078h, 0.12901784h, -0.10123104h, -0.2129385h, -0.15062876h, 0.019824497h, -0.015181707h, 0.070795976h, 0.13549626h), result);
                result = MulAdd(src[i + 1][j - 1], half3x4(-0.036070887h, -0.2733308h, 0.05836442h, -0.06817092h, -0.08980838h, -0.514616h, 0.2965783h, 0.103823625h, -0.015213521h, -0.16376303h, 0.0017071419h, -0.0922202h), result);
                result = MulAdd(src[i + 1][j], half3x4(-0.053406045h, 0.011273207h, -0.05544644h, 0.09432561h, -0.04143601h, -0.0783786h, -0.39899537h, 0.040322974h, -0.046442945h, 0.052499074h, 0.03397099h, 0.05516481h), result);
                result = MulAdd(src[i + 1][j + 1], half3x4(0.35976252h, 0.197882h, 0.031213427h, -0.02211337h, 0.7940331h, 0.327452h, 0.30120966h, 0.03181121h, 0.13782893h, 0.060073618h, -0.00940469h, -0.0358819h), result);

                tex1_UAV[destPos] = result;
            }
        }
    }
}

[bgfx::PASS(2, "Feature Processing Conv-4x3x3x8")]
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
                half4 result = half4(0.022899346h, 0.033619333h, 0.030674957h, -0.017047008h);
                result = MulAdd(max(src[i - 1][j - 1], half4(0)), half4x4(-0.103708945h, -0.050891697h, -0.2067834h, -0.033582103h, -0.08676132h, 0.15528207h, -0.10070597h, -0.13641205h, 0.030959459h, 0.12798834h, -0.058627255h, -0.008511715h, 0.023304658h, -0.027084433h, 0.120355256h, -0.023104342h), result);
                result = MulAdd(max(src[i - 1][j], half4(0)), half4x4(0.0550643h, -0.26851672h, 0.11073926h, 0.21989855h, 0.012853378h, 0.028077757h, 0.073306665h, -0.04551125h, 0.16005373h, -0.018154016h, -0.12347146h, -0.07590073h, -0.10193998h, 0.084696375h, 0.04041413h, -0.030883553h), result);
                result = MulAdd(max(src[i - 1][j + 1], half4(0)), half4x4(-0.04816972h, 0.0804637h, 0.0071406h, -0.08482986h, 0.11176785h, 0.060121994h, -0.047804814h, -0.036170192h, 0.01989302h, -0.12537469h, -0.16283676h, 0.19132937h, -0.052577138h, -0.005143432h, 0.045614418h, 0.04198543h), result);
                result = MulAdd(max(src[i][j - 1], half4(0)), half4x4(-0.33660156h, 0.036350835h, -0.4623589h, -0.04140598h, 0.2436438h, -0.044735093h, 0.20876355h, -0.004252532h, 0.81046224h, -0.18550895h, 0.32743093h, 0.109012894h, -0.34675312h, -0.03464997h, -0.09489919h, -0.07961427h), result);
                result = MulAdd(max(src[i][j], half4(0)), half4x4(-0.08862038h, -0.8168393h, 0.03584266h, 0.32159033h, 0.06634099h, 0.2985745h, -0.18204363h, -0.016070427h, 0.35503992h, 1.1388919h, 0.16171643h, -0.63834023h, -0.0037699202h, -0.27919513h, -0.20949292h, 0.03270466h), result);
                result = MulAdd(max(src[i][j + 1], half4(0)), half4x4(0.021701936h, -0.04537874h, -0.05514495h, 0.23225744h, 0.024968185h, 0.1816845h, 0.03485249h, -0.28249854h, -0.37759346h, -0.3225813h, 0.021595621h, 0.17104608h, -0.0044055753h, 0.01621266h, -0.015169225h, 0.08956203h), result);
                result = MulAdd(max(src[i + 1][j - 1], half4(0)), half4x4(-0.033255238h, -0.110517226h, 0.10664505h, 0.019566126h, -0.0695305h, 0.059743922h, -0.19161415h, -0.024217626h, -0.08578889h, -0.16358584h, -0.23050265h, -0.004697784h, -0.060790297h, 0.1174991h, 0.08205285h, -0.011846926h), result);
                result = MulAdd(max(src[i + 1][j], half4(0)), half4x4(0.6119327h, 0.0791928h, -0.118774265h, 0.42233524h, -0.16248553h, -0.017692063h, 0.13530938h, -0.3207985h, -0.147722h, -0.24525681h, 0.05243329h, -0.38583818h, 0.5147888h, -0.072632834h, -0.6014986h, 0.26713687h), result);
                result = MulAdd(max(src[i + 1][j + 1], half4(0)), half4x4(0.23735437h, -0.032110002h, 0.17445332h, -0.3272264h, 0.020623574h, 0.26734766h, -0.16806662h, 0.0796467h, -0.34921628h, 0.016648084h, -0.14200358h, 0.59190625h, 0.13177821h, 0.11139572h, -0.14972521h, -0.16784541h), result);
                result = MulAdd(max(-src[i - 1][j - 1], half4(0)), half4x4(-0.047283772h, -0.003196778h, 0.44890094h, 0.14619343h, -0.17113213h, -0.068454474h, 0.07681565h, -0.04306807h, -0.0022641511h, -0.20954822h, 0.0344229h, 0.014815744h, -0.010632933h, 0.13355999h, -0.0860752h, -0.069001146h), result);
                result = MulAdd(max(-src[i - 1][j], half4(0)), half4x4(0.11664345h, 0.099102855h, 0.1642523h, 0.047408774h, 0.038490184h, 0.16064398h, -0.08694127h, -0.2149453h, -0.1413128h, -0.06531084h, -0.10105762h, 0.19743964h, 0.10458527h, -0.04133969h, 0.1425028h, -0.01328308h), result);
                result = MulAdd(max(-src[i - 1][j + 1], half4(0)), half4x4(0.0138432095h, -0.20053013h, 0.079355195h, 0.273772h, 0.05484276h, 0.13891658h, 0.16240036h, -0.25245088h, 0.011192391h, 0.104164094h, 0.08112111h, -0.250435h, -0.0559613h, -0.031029798h, -0.015725998h, 0.09240792h), result);
                result = MulAdd(max(-src[i][j - 1], half4(0)), half4x4(0.18754779h, -0.33171803h, 0.34917468h, 0.29074225h, -0.37954012h, 0.20898043h, -0.24973525h, -0.13707505h, -0.31585664h, 0.13607393h, -0.29118514h, 0.015055187h, 0.18549949h, -0.06351915h, 0.2823401h, -0.00019733967h), result);
                result = MulAdd(max(-src[i][j], half4(0)), half4x4(0.10060476h, 0.2883022h, -0.15810104h, -0.041112892h, 0.31050095h, 0.18517002h, 0.020033397h, -0.35919502h, -0.17903808h, -0.43506318h, -0.14783014h, 0.20092726h, -0.002020754h, 0.13320895h, 0.040995706h, 0.052643474h), result);
                result = MulAdd(max(-src[i][j + 1], half4(0)), half4x4(-0.014892139h, 0.005828587h, 0.044784732h, -0.27272886h, 0.21069369h, 0.044396695h, -0.03411123h, 0.031441864h, 0.17224072h, 0.1708587h, -0.00729118h, -0.13070418h, -0.19128975h, -0.09342688h, -0.051133234h, -0.089075714h), result);
                result = MulAdd(max(-src[i + 1][j - 1], half4(0)), half4x4(0.08799108h, 0.04157696h, -0.15010124h, 0.26832178h, -0.0040120087h, 0.040308744h, 0.17632529h, -0.09464763h, 0.07786305h, 0.038288828h, 0.40799135h, 0.037377868h, -0.049877923h, -0.25080636h, 0.00068664295h, 0.0013101585h), result);
                result = MulAdd(max(-src[i + 1][j], half4(0)), half4x4(0.0353459h, -0.21445732h, 0.112647906h, -0.3513759h, 0.16887255h, 0.3224789h, -0.17073384h, 0.10875396h, 0.18919177h, 0.14288992h, 0.07364533h, 0.20205943h, -0.34363645h, -0.3520186h, 0.6763608h, -0.19051236h), result);
                result = MulAdd(max(-src[i + 1][j + 1], half4(0)), half4x4(-0.032245517h, 0.039594565h, -0.11825768h, 0.16509856h, 0.11749939h, -0.005166539h, 0.10740687h, -0.3794017h, 0.12722437h, 0.14066173h, 0.08025407h, -0.34773758h, -0.027300838h, -0.08963159h, 0.29774833h, 0.053532287h), result);

                tex2_UAV[destPos] = result;
            }
        }
    }
}

[bgfx::PASS(3, "Feature Processing Conv-4x3x3x8")]
[bgfx::PASS_IO("tex2", "tex1_UAV")]
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
                half4 result = half4(0.04921464h, -0.0011432811h, 0.062071066h, -0.06594219h);
                result = MulAdd(max(src[i - 1][j - 1], half4(0)), half4x4(-0.0714004h, -0.0545495h, -0.050848898h, 0.04724593h, 0.2214181h, 0.26353878h, 0.07314053h, -0.18771721h, 0.06282607h, -0.03720548h, 0.020577375h, -0.08951135h, 0.40820515h, 0.012179098h, 0.52947706h, -0.48448065h), result);
                result = MulAdd(max(src[i - 1][j], half4(0)), half4x4(0.10311368h, -0.10970221h, 0.07008208h, -0.07143153h, 0.073753305h, 0.03786335h, -0.4312538h, -0.17680745h, -0.15527713h, -0.06711554h, -0.21828765h, 0.27252844h, -0.0025433605h, 0.31595528h, -0.06065309h, 0.059542265h), result);
                result = MulAdd(max(src[i - 1][j + 1], half4(0)), half4x4(-0.036736265h, 0.08704119h, -0.06530063h, 0.04546563h, 0.010335546h, -0.040761005h, -0.021500558h, 0.104531065h, 0.094652064h, -0.05088704h, 0.14768088h, -0.08585825h, 0.057680476h, 0.09885713h, 0.18074304h, -0.14277679h), result);
                result = MulAdd(max(src[i][j - 1], half4(0)), half4x4(-0.04810641h, -0.01735864h, -0.06405213h, 0.04889552h, -0.011552542h, -0.04617259h, 0.023976233h, 0.27587202h, -0.117965676h, -0.07052052h, -0.030583147h, -0.036600694h, -0.08542387h, -0.053850796h, 0.27242282h, -0.73792183h), result);
                result = MulAdd(max(src[i][j], half4(0)), half4x4(-0.1340838h, 0.1256252h, -0.040528856h, 0.13554344h, -0.13733707h, -0.14641404h, 0.42666963h, -0.4933124h, -0.34908h, 0.054332364h, -0.2768947h, 0.44689894h, 0.42182985h, -0.027279109h, -0.17136064h, -0.009496184h), result);
                result = MulAdd(max(src[i][j + 1], half4(0)), half4x4(0.075086355h, -0.025501372h, 0.02172236h, -0.052761186h, -0.055753034h, -0.028023237h, -0.08829973h, 0.14333946h, 0.062496934h, 0.034493748h, 0.17640088h, -0.084869936h, 0.21283653h, 0.1184779h, 0.0016387368h, -0.1498814h), result);
                result = MulAdd(max(src[i + 1][j - 1], half4(0)), half4x4(0.054841094h, 0.040639404h, -0.025044259h, -0.071105786h, -0.07473824h, -0.04719771h, 0.016553668h, -0.10028357h, 0.009365985h, -0.0133521445h, 0.022320358h, -0.09318326h, 0.17342545h, 0.19281831h, 0.16737404h, -0.09583887h), result);
                result = MulAdd(max(src[i + 1][j], half4(0)), half4x4(-0.03950585h, 0.091417804h, -0.021395942h, 0.08735149h, -0.029363452h, -0.04763804h, -0.1430701h, 0.15344201h, -0.006604305h, 0.05897304h, -0.13595524h, 0.083323576h, 0.008187976h, 0.12946083h, 0.14983748h, -0.08178542h), result);
                result = MulAdd(max(src[i + 1][j + 1], half4(0)), half4x4(-0.00046765045h, -0.07914878h, 0.03529457h, -0.007752294h, -0.10084779h, -0.1531338h, -0.1408283h, 0.20638838h, 0.01466853h, -0.059309185h, -0.11161097h, 0.08481583h, 0.090416916h, 0.081118226h, 0.08677104h, -0.20095336h), result);
                result = MulAdd(max(-src[i - 1][j - 1], half4(0)), half4x4(0.3200496h, -0.049090706h, 0.11554867h, -0.11949655h, -0.18064958h, 0.0012254696h, -0.032284267h, 0.00076361356h, -0.13239916h, -0.13838826h, -0.20345089h, 0.00692921h, -0.2271236h, -0.07132879h, -0.097703665h, 0.29881954h), result);
                result = MulAdd(max(-src[i - 1][j], half4(0)), half4x4(0.4095371h, 0.3008338h, -0.43109173h, -0.495734h, 0.15016843h, -0.3890023h, 1.0669806h, -0.20876339h, -0.32241493h, -0.10387533h, -0.018227777h, 0.1349976h, -0.0019588785h, -0.19263229h, 0.38952798h, 0.08135965h), result);
                result = MulAdd(max(-src[i - 1][j + 1], half4(0)), half4x4(0.01517036h, -0.51562387h, -0.13939962h, -0.23287989h, 0.09597558h, 0.017624658h, 0.16989397h, -0.09395267h, -0.29612765h, 0.11843327h, -0.07493133h, 0.14523852h, 0.040488124h, 0.016568637h, 0.10204776h, -0.13137013h), result);
                result = MulAdd(max(-src[i][j - 1], half4(0)), half4x4(-0.1512155h, -0.12732185h, 0.08002965h, 0.024762904h, 0.05106389h, 0.011125884h, -0.043196492h, -0.17617282h, 0.09791206h, 0.120643355h, 0.075500526h, 0.10948051h, 0.04969893h, -0.20776172h, -0.06905779h, -0.20245977h), result);
                result = MulAdd(max(-src[i][j], half4(0)), half4x4(-0.41836104h, -0.82896453h, -0.20962712h, 0.7804863h, 0.17322528h, 0.53994787h, -0.18730208h, -0.021233026h, 0.7417944h, -0.4544313h, 0.23165174h, -0.63969344h, 0.09383021h, -0.046137553h, -0.07796646h, 0.11413524h), result);
                result = MulAdd(max(-src[i][j + 1], half4(0)), half4x4(-0.32532063h, 0.09456587h, 0.43708017h, -0.40595353h, 0.061229162h, 0.006663704h, -0.19821976h, 0.07661682h, -0.21427135h, 0.17748164h, -0.31958643h, 0.3883502h, 0.068938896h, 0.022886515h, 0.022923468h, -0.04269318h), result);
                result = MulAdd(max(-src[i + 1][j - 1], half4(0)), half4x4(0.23775512h, 0.04026384h, 0.12276414h, -0.2545085h, 0.0894177h, 0.115443565h, 0.029124375h, 0.08887401h, -0.0057824687h, 0.017655179h, -0.025270017h, -0.06643964h, 0.01316084h, 0.024039604h, 0.034566984h, -0.12682836h), result);
                result = MulAdd(max(-src[i + 1][j], half4(0)), half4x4(0.036596492h, 0.22772355h, -0.05508538h, -0.18005793h, -0.06432669h, -0.037058707h, 0.2718052h, -0.10313161h, 0.016055575h, 0.051271006h, -0.038919963h, -0.036601298h, -0.019457681h, 0.03805731h, 0.03252896h, -0.07179724h), result);
                result = MulAdd(max(-src[i + 1][j + 1], half4(0)), half4x4(0.15046261h, 0.13090402h, -0.023847125h, -0.039356075h, 0.045424663h, -0.20594294h, 0.2154043h, -0.18429665h, -0.07969159h, 0.08719893h, -0.057626463h, 0.08344988h, -0.018651528h, 0.047302175h, 0.060727824h, -0.035960387h), result);

                tex1_UAV[destPos] = result;
            }
        }
    }
}

[bgfx::PASS(4, "Reconstruction Conv-4x3x3x8, Depth-to-Space")]
[bgfx::PASS_IO("INPUT, tex1", "OUTPUT")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass4(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1) + (tid.xy / 8) * 16;

    const uint2 outputSize = GetOutputSize();
    if (gxy.x >= outputSize.x || gxy.y >= outputSize.y)
    {
        return;
    }

    float2 inputPt = GetInputPt();
    float2 outputPt = GetOutputPt();

    float2 pos = ((gxy >> 1) + 0.5f) * inputPt;

    half4 a = half4(tex1.SampleLevel(sam, pos - inputPt, 0));
    half4 b = half4(tex1.SampleLevel(sam, pos + float2(-inputPt.x, 0), 0));
    half4 c = half4(tex1.SampleLevel(sam, pos + float2(-inputPt.x, inputPt.y), 0));
    half4 d = half4(tex1.SampleLevel(sam, pos + float2(0, -inputPt.y), 0));
    half4 e = half4(tex1.SampleLevel(sam, pos, 0));
    half4 f = half4(tex1.SampleLevel(sam, pos + float2(0, inputPt.y), 0));
    half4 g = half4(tex1.SampleLevel(sam, pos + float2(inputPt.x, -inputPt.y), 0));
    half4 h = half4(tex1.SampleLevel(sam, pos + float2(inputPt.x, 0), 0));
    half4 i = half4(tex1.SampleLevel(sam, pos + float2(inputPt.x, inputPt.y), 0));

    half4 result = half4(-0.0031417734h, -0.002754766h, -0.004053268h, -0.003937834h);
    result = MulAdd(max(a, half4(0)), half4x4(-0.04508749h, 0.00222134h, 0.013338363h, -0.0067310617h, 0.099346675h, 0.05804196h, 0.018694466h, -0.008126048h, 0.007771997h, -0.0072556734h, -0.008293339h, 0.001518462h, -0.06296499h, -0.064195156h, 0.0727399h, 0.044078834h), result);
    result = MulAdd(max(b, half4(0)), half4x4(0.20800652h, -0.016071903h, -0.08095607h, -0.03472411h, -0.20690396h, 0.061331827h, -0.10627648h, 0.12838624h, 0.036534917h, -0.006113497h, 0.029266752h, -0.002263159h, 0.2937966h, -0.05544609h, 0.14546311h, -0.01290958h), result);
    result = MulAdd(max(c, half4(0)), half4x4(0.07792222h, -7.288649e-05h, 0.2800036h, 0.019709835h, -0.010950291h, 0.021879988h, 0.037608813h, 0.055267945h, 0.018646395h, -0.016691998h, 0.03787624h, -0.006547077h, 0.03214097h, -0.018541625h, 0.12142825h, -0.070806496h), result);
    result = MulAdd(max(d, half4(0)), half4x4(-0.009798109h, -0.06606263h, 0.0010101331h, 0.009924258h, -0.10272075h, -0.07983353h, 0.028398676h, 0.04967719h, 0.12467993h, 0.06775066h, 0.017111637h, 0.012814711h, 0.0031143876h, -0.0902014h, 0.11242646h, 0.076476306h), result);
    result = MulAdd(max(e, half4(0)), half4x4(0.07650971h, 0.35096344h, 0.0612814h, 0.06036218h, 0.253547h, -0.0460987h, -0.11145313h, -0.48844674h, -0.050644107h, 0.038706005h, 0.19390784h, 0.035322774h, -0.010191005h, 0.58071h, -0.2856661h, -0.009533105h), result);
    result = MulAdd(max(f, half4(0)), half4x4(-0.071486905h, -0.036179904h, -0.07303894h, 0.19301178h, -0.11499898h, -0.024847068h, -0.0027055284h, 0.20373714h, -0.09671404h, -0.020897992h, -0.25572056h, -0.008931707h, -0.13582602h, -0.006546881h, -0.16154496h, 0.26454738h), result);
    result = MulAdd(max(g, half4(0)), half4x4(0.005463064h, 0.006769753h, 0.0039625713h, 0.014121269h, -0.068200685h, -0.057850275h, 0.008622973h, 0.061149873h, 0.017436448h, 0.11660872h, -0.02994459h, 0.008590145h, -0.03223439h, 0.052557915h, -0.011846354h, 0.03523357h), result);
    result = MulAdd(max(h, half4(0)), half4x4(-0.00015264735h, 0.0012872831h, 0.021878848h, 0.022240406h, 0.01822283h, -0.008284247h, -0.018443186h, -0.04997753h, -0.111760505h, -0.20911667h, 0.006166832h, 0.14597091h, 0.02305932h, -0.16312876h, 0.023375351h, -0.028755601h), result);
    result = MulAdd(max(i, half4(0)), half4x4(0.013701143h, 0.010794129h, 0.0024321147h, -0.018976321h, 0.0365032h, -0.006783485h, 0.01046472h, -0.08473902h, 0.057523903h, 0.029831914h, 0.0040916028h, -0.2046352h, 0.03542h, -0.034598h, 0.0031058635h, -0.20746285h), result);
    result = MulAdd(max(-a, half4(0)), half4x4(0.09283864h, -0.0035849356h, 0.013190911h, -0.035437535h, 0.035798516h, 0.022954805h, -0.0029692063h, -0.006633743h, -0.13456796h, -0.011448714h, 0.011536131h, 0.046695728h, -0.0359048h, -0.01144856h, -0.0027279712h, 0.0065755467h), result);
    result = MulAdd(max(-b, half4(0)), half4x4(-0.14295974h, -0.0034393691h, 0.0051469817h, -0.021334402h, -0.05882422h, -0.003004241h, 0.011182507h, 0.0015169785h, 0.08474255h, 0.1255887h, -0.23984577h, 0.07119401h, -0.12547183h, 0.038449038h, 0.007738907h, 0.031506266h), result);
    result = MulAdd(max(-c, half4(0)), half4x4(-0.028237654h, 0.010254326h, -0.11843009h, 0.03034298h, -0.038323015h, 0.0026470951h, -0.060652684h, 0.0022312272h, -0.022539174h, -0.01008126h, 0.14868541h, 0.02881852h, -0.05327277h, -0.012296453h, -0.21280704h, -0.021286633h), result);
    result = MulAdd(max(-d, half4(0)), half4x4(-0.034825645h, 0.0877418h, -0.009103147h, 0.041650586h, 0.0135769h, -0.005229229h, 0.00082947424h, -0.0020421906h, 0.12402267h, 0.007698874h, -0.056337915h, -0.006580138h, -0.018867968h, -0.08487179h, -0.020938644h, -0.029210499h), result);
    result = MulAdd(max(-e, half4(0)), half4x4(-0.37082648h, -0.30321857h, -0.22912364h, -0.07368761h, 0.15169628h, 0.0013253551h, 0.09232649h, 0.011408914h, 0.06347244h, -0.377988h, 0.13980117h, -0.41065913h, -0.00040237256h, -0.23220152h, -0.03643865h, -0.10101427h), result);
    result = MulAdd(max(-f, half4(0)), half4x4(0.10692653h, 0.049867555h, -0.011915118h, -0.10688069h, 0.042109665h, -0.017163716h, 0.10852331h, -0.0088934945h, 0.06780516h, -0.017808875h, 0.26564032h, 0.0523693h, 0.099033475h, 0.042864073h, 0.18299587h, -0.13503626h), result);
    result = MulAdd(max(-g, half4(0)), half4x4(0.07014404h, 0.08841395h, 0.01895322h, 0.0036451078h, -0.00933168h, 0.044764042h, -0.0034986525h, 0.010701783h, -0.043601245h, -0.1375109h, 0.0039965697h, -0.054331h, 0.018830067h, 0.040386382h, 0.007759782h, -0.012478715h), result);
    result = MulAdd(max(-h, half4(0)), half4x4(0.024152381h, -0.11462646h, 0.07005155h, 0.0424638h, -0.0048070764h, 0.06089261h, -0.036675487h, 0.057459857h, 0.02478629h, 0.2926517h, -0.08248396h, -0.053960845h, 0.013205341h, 0.09851673h, -0.04310949h, -0.001428641h), result);
    result = MulAdd(max(-i, half4(0)), half4x4(0.016168298h, 0.009701502h, 0.0064305146h, -0.068672284h, -0.044653386h, -0.016051823h, -0.015055443h, 0.032019246h, -0.0829852h, -0.011304939h, 0.0023902296h, 0.30322486h, -0.023831543h, -0.0046928846h, 0.026961725h, 0.16314326h), result);

    pos -= 0.5f * outputPt;
    OUTPUT[gxy] = float4(result.x + half3(INPUT.SampleLevel(sam1, pos, 0).rgb), 1);

    ++gxy.x;
    pos.x += outputPt.x;
    OUTPUT[gxy] = float4(result.y + half3(INPUT.SampleLevel(sam1, pos, 0).rgb), 1);

    ++gxy.y;
    pos.y += outputPt.y;
    OUTPUT[gxy] = float4(result.w + half3(INPUT.SampleLevel(sam1, pos, 0).rgb), 1);

    --gxy.x;
    pos.x -= outputPt.x;
    OUTPUT[gxy] = float4(result.z + half3(INPUT.SampleLevel(sam1, pos, 0).rgb), 1);
}
